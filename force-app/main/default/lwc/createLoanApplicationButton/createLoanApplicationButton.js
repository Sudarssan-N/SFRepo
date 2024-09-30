import { LightningElement, api, track, wire } from 'lwc';
import hasPermission from '@salesforce/customPermission/Banker_Special_Access';
import getActiveSession from '@salesforce/apex/CustomerSessionController.getActiveSession';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, MessageContext } from 'lightning/messageService';
import SESSION_MESSAGE from '@salesforce/messageChannel/SessionMessageChannel__c';

export default class CreateLoanApplicationButton extends LightningElement {
    @api recordId;
    @track isButtonVisible = false;
    @track isLoading = true;
    @track flowInitialized = false;
    @track flowInputVariables = [];

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this.checkAccessAndSession();
        this.subscribeToMessageChannel();
    }

    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                SESSION_MESSAGE,
                (message) => this.handleSessionMessage(message)
            );
        }
    }

    handleSessionMessage(message) {
        if (message.sessionCreated) {
            this.checkAccessAndSession();
        }
    }

    async checkAccessAndSession() {
        try {
            this.isLoading = true;
            if (hasPermission) {
                const sessionActive = await getActiveSession({ accountId: this.recordId });
                this.isButtonVisible = sessionActive;
            } else {
                this.isButtonVisible = false;
            }
        } catch (error) {
            console.error('Error checking access and session:', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleCreateLoanApplication() {
        this.flowInputVariables = [
            {
                name: 'AccountId',
                type: 'String',
                value: this.recordId,
            },
        ];
        this.flowInitialized = true;
    }

    handleStatusChange(event) {
        if (event.detail.status === 'FINISHED') {
            this.flowInitialized = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Loan Application created successfully.',
                    variant: 'success',
                })
            );
        }
    }
}
