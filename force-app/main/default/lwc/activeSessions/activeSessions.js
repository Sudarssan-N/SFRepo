import { LightningElement, track, wire } from 'lwc';
import getActiveSessions from '@salesforce/apex/ActiveSessionsController.getActiveSessions';
import deleteSession from '@salesforce/apex/ActiveSessionsController.deleteSession';
import { refreshApex } from '@salesforce/apex';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const actions = [
    { label: 'Delete Session', name: 'delete_session' }
];

const columns = [
    { label: 'Session Name', fieldName: 'Name' },
    { label: 'Account Name', fieldName: 'AccountName', type: 'text' },
    { label: 'Authenticated Timestamp', fieldName: 'Authenticated_Timestamp__c', type: 'date', typeAttributes: { 
        year: "numeric", 
        month: "2-digit", 
        day: "2-digit", 
        hour: "2-digit", 
        minute: "2-digit", 
        second: "2-digit" 
    } },
    {
        type: 'action',
        typeAttributes: { rowActions: actions },
    },
];

export default class ActiveSessions extends LightningElement {
    @track sessions = [];
    columns = columns;

    @wire(getActiveSessions)
    wiredSessions(result) {
        this.wiredSessionsResult = result;
        const {data, error} = result;
        if (data) {
            this.sessions = data.map(session => {
                return {
                    ...session,
                    AccountName: session.Account__r.Name,
                };
            });
        } else if (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error loading sessions',
                    message: error.body.message,
                    variant: 'error',
                })
            );
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'delete_session') {
            this.deleteSession(row);
        }
    }

    deleteSession(row) {
        deleteSession({ sessionId: row.Id })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Session deleted successfully',
                        variant: 'success',
                    })
                );
                // Refresh the sessions list
                return refreshApex(this.wiredSessionsResult);
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error deleting session',
                        message: error.body.message,
                        variant: 'error',
                    })
                );
            });
    }
}
