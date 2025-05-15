import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import generateCustomerSummary from '@salesforce/apex/CustomerSummaryControllerGemini.generateCustomerSummary';
import handleAction from '@salesforce/apex/ActionHandler.handleAction';

export default class CustomerSummary extends NavigationMixin(LightningElement) {
    @api recordId; // Contact's record Id
    isLoading = false;
    summary = '';
    detailedSummary = '';
    conversationStarters = [];
    actionableActions = []; // Will store the parsed actions array
    error = '';
    showDetails = false;
    satisfactionScore = '';
    expectedSentiment = '';

    get toggleLabel() {
        return this.showDetails ? 'Hide Detailed Summary' : 'Show Detailed Summary';
    }

    // Helper method to extract JSON from the returned string
    extractJson(jsonLikeString) {
        const firstBrace = jsonLikeString.indexOf('{');
        const lastBrace = jsonLikeString.lastIndexOf('}');
        if (firstBrace !== -1 && lastBrace !== -1 && lastBrace > firstBrace) {
            return jsonLikeString.substring(firstBrace, lastBrace + 1);
        }
        return null;
    }

    handleGenerateSummary() {
        this.isLoading = true;
        this.error = '';
        this.summary = '';
        this.detailedSummary = '';
        this.conversationStarters = [];
        this.actionableActions = [];
        this.satisfactionScore = '';
        this.expectedSentiment = '';

        generateCustomerSummary({ contactId: this.recordId })
            .then((result) => {
                const parsedResult = JSON.parse(result);
                
                // Extract satisfaction score from conciseSummary
                const conciseSummary = parsedResult.conciseSummary;
                const scoreMatch = conciseSummary.match(/Customer satisfaction score: (\d{1,2})\/10/);
                this.satisfactionScore = scoreMatch ? scoreMatch[1] : 'N/A';
                
                // Remove the satisfaction score from the summary to avoid duplication
                this.summary = conciseSummary.replace(/Customer satisfaction score: \d{1,2}\/10\.?/, '').trim();
                this.detailedSummary = parsedResult.fullSummary;
                this.conversationStarters = parsedResult.conversationPrompts;
                this.expectedSentiment = parsedResult.expectedSentiment || 'Not available';
            })
            .catch((error) => {
                this.error = 'Error generating summary: ' + (error.body ? error.body.message : error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // When an action button is clicked, call the Apex action handler
    handleActionClick(event) {
        const actionType = event.target.dataset.action;
        handleAction({ action: actionType, contactId: this.recordId })
            .then((url) => {
                // Use NavigationMixin to navigate to the returned URL
                this[NavigationMixin.Navigate]({
                    type: 'standard__webPage',
                    attributes: {
                        url: url
                    }
                });
            })
            .catch((error) => {
                this.error = 'Error processing action: ' + (error.body ? error.body.message : error);
            });
    }

    toggleDetails() {
        this.showDetails = !this.showDetails;
    }
}