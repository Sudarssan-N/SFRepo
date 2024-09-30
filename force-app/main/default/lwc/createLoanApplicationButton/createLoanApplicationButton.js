import { LightningElement, api, track } from 'lwc';
import hasPermission from '@salesforce/customPermission/Banker_Special_Access';
import getActiveSession from '@salesforce/apex/CustomerSessionController.getActiveSession';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CreateLoanApplicationButton extends LightningElement {
    @api recordId;
    @track isButtonVisible = false;
    @track isLoading = true;
    @track flowInitialized = false;

    connectedCallback() {
        this.checkAccessAndSession();
    }

    async checkAccessAndSession() {
        try {
            if (hasPermission) {
                const sessionActive = await getActiveSession({ accountId: this.recordId });
                if (sessionActive) {
                    this.isButtonVisible = true;
                }
            }
        } catch (error) {
            console.error('Error checking access and session:', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleCreateLoanApplication() {
        // Start the Flow
        const flow = this.template.querySelector('lightning-flow');
        if (flow) {
            const inputVariables = [
                {
                    name: 'AccountId',
                    type: 'String',
                    value: this.recordId,
                },
            ];
            flow.startFlow('Loan_Application_Wizard', inputVariables);
            this.flowInitialized = true;
        } else {
            console.error('Flow component not found');
        }
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
