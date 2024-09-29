import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, createRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getActiveSession from '@salesforce/apex/CustomerSessionController.getActiveSession';

// Import the Customer Session object and its fields
import CUSTOMER_SESSION_OBJECT from '@salesforce/schema/Customer_Session__c';
import ACCOUNT_FIELD from '@salesforce/schema/Customer_Session__c.Account__c';
import AUTH_TIMESTAMP_FIELD from '@salesforce/schema/Customer_Session__c.Authenticated_Timestamp__c';
import SESSION_ACTIVE_FIELD from '@salesforce/schema/Customer_Session__c.Session_Active__c';

// Import security question and answer fields
import SECURITY_QUESTION_1 from '@salesforce/schema/Account.Security_Question_1__c';
import SECURITY_ANSWER_1 from '@salesforce/schema/Account.Security_Answer_1__c';
import SECURITY_QUESTION_2 from '@salesforce/schema/Account.Security_Question_2__c';
import SECURITY_ANSWER_2 from '@salesforce/schema/Account.Security_Answer_2__c';
import SECURITY_QUESTION_3 from '@salesforce/schema/Account.Security_Question_3__c';
import SECURITY_ANSWER_3 from '@salesforce/schema/Account.Security_Answer_3__c';
// Continue importing up to 7 questions and answers...

const FIELDS = [
    SECURITY_QUESTION_1,
    SECURITY_ANSWER_1,
    SECURITY_QUESTION_2,
    SECURITY_ANSWER_2,
    SECURITY_QUESTION_3,
    SECURITY_ANSWER_3,
    // Add other fields up to question 7
];


export default class AuthenticateCustomer extends LightningElement {
    @api recordId;
    @track showQuestions = false;
    @track securityQuestions = [];
    @track enteredAnswers = {};
    @track isAuthenticated = false;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    account;

    handleAuthenticate() {
        this.showQuestions = true;
        this.prepareQuestions();
    }

    connectedCallback() {
        this.checkActiveSession();
    }

    checkActiveSession() {
        getActiveSession({ accountId: this.recordId })
            .then(result => {
                if (result) {
                    this.isAuthenticated = true;
                }
            })
            .catch(error => {
                console.error('Error checking active session:', error);
            });
    }

    handleSubmitAnswers() {
        let allCorrect = true;
        this.securityQuestions.forEach(question => {
            const enteredAnswer = this.enteredAnswers[question.Id];
            const correctAnswer = question.answer;
            if (
                enteredAnswer.trim().toLowerCase() !== correctAnswer.trim().toLowerCase()
            ) {
                allCorrect = false;
            }
        });

        if (allCorrect) {
            this.isAuthenticated = true;
            this.showQuestions = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Customer authenticated successfully.',
                    variant: 'success',
                })
            );
            // Create a customer session
            this.createCustomerSession();
        } else {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Authentication Failed',
                    message: 'One or more answers are incorrect.',
                    variant: 'error',
                })
            );
        }
    }

    createCustomerSession() {
        const fields = {};
        fields[ACCOUNT_FIELD.fieldApiName] = this.recordId;
        fields[AUTH_TIMESTAMP_FIELD.fieldApiName] = new Date().toISOString();
        fields[SESSION_ACTIVE_FIELD.fieldApiName] = true;

        const recordInput = { apiName: CUSTOMER_SESSION_OBJECT.objectApiName, fields };

        createRecord(recordInput)
            .then(sessionRecord => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Session Created',
                        message: `Session ${sessionRecord.id} created successfully.`,
                        variant: 'success',
                    })
                );
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error creating session',
                        message: error.body.message,
                        variant: 'error',
                    })
                );
            });
    }
}
