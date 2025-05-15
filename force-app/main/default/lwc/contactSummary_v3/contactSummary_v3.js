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
    satisfactionExplanation = '';
    sentimentLabel = ''; // To store the sentiment label (e.g., "Mixed")
    sentimentExplanation = ''; // To store the sentiment explanation
    scoreColorClass = '';
    sentimentColorClass = '';

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

    // Determine color class for satisfaction score
    getScoreColorClass(score) {
        const scoreNum = parseInt(score, 10);
        if (isNaN(scoreNum)) return '';
        if (scoreNum >= 1 && scoreNum <= 4) return 'score-red';
        if (scoreNum >= 5 && scoreNum <= 7) return 'score-yellow';
        if (scoreNum >= 8 && scoreNum <= 10) return 'score-green';
        return '';
    }

    // Determine color class for sentiment (apply to label only)
    getSentimentColorClass(sentiment) {
        if (!sentiment) return '';
        const lowerSentiment = sentiment.toLowerCase();
        if (lowerSentiment.includes('positive')) return 'sentiment-positive';
        if (lowerSentiment.includes('neutral')) return 'sentiment-neutral';
        if (lowerSentiment.includes('negative')) return 'sentiment-negative';
        return 'sentiment-neutral'; // Default to neutral for descriptive phrases
    }

    handleGenerateSummary() {
        this.isLoading = true;
        this.error = '';
        this.summary = '';
        this.detailedSummary = '';
        this.conversationStarters = [];
        this.actionableActions = [];
        this.satisfactionScore = '';
        this.satisfactionExplanation = '';
        this.sentimentLabel = '';
        this.sentimentExplanation = '';
        this.scoreColorClass = '';
        this.sentimentColorClass = '';

        generateCustomerSummary({ contactId: this.recordId })
            .then((result) => {
                const parsedResult = JSON.parse(result);
                
                this.summary = parsedResult.conciseSummary || '';
                this.detailedSummary = parsedResult.fullSummary || '';
                this.conversationStarters = parsedResult.conversationPrompts || [];
                this.satisfactionScore = parsedResult.satisfactionScore || 'N/A';
                this.satisfactionExplanation = parsedResult.satisfactionExplanation || 'Not available';

                // Split expectedSentiment into label and explanation
                const expectedSentiment = parsedResult.expectedSentiment || 'Not available';
                const sentimentParts = expectedSentiment.split('. ');
                if (sentimentParts.length > 1) {
                    this.sentimentLabel = sentimentParts[0].replace('Perceived Sentiment:', '').trim();
                    this.sentimentExplanation = sentimentParts.slice(1).join('. ').trim();
                } else {
                    this.sentimentLabel = expectedSentiment.replace('Perceived Sentiment:', '').trim();
                    this.sentimentExplanation = 'No explanation available.';
                }

                // Apply color classes
                this.scoreColorClass = this.getScoreColorClass(this.satisfactionScore);
                this.sentimentColorClass = this.getSentimentColorClass(this.sentimentLabel);

                // // Clean up the conversation starters array - remove any empty entries or numbering
                // this.conversationStarters = this.conversationStarters
                //     .filter(starter => starter && starter.trim() !== '')
                //     .map(starter => {
                //         // Remove any leading numbers like "1. ", "2. ", etc.
                //         return starter.replace(/^\d+\.\s+/, '').trim();
                //     });
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