// customerChat.js
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import generateChatResponse from '@salesforce/apex/CustomerChatController.generateChatResponse';
import saveFeedback from '@salesforce/apex/CustomerChatController.saveFeedback';

export default class CustomerChat extends LightningElement {
    @api recordId;
    @track messages = [];
    @track userInput = '';

    messageCounter = 0;

    connectedCallback() {
        this.addMessage('system', 'Hello! How can I help you today?');
    }

    addMessage(sender, text) {
        this.messages = [
            ...this.messages,
            {
                id: this.messageCounter++,
                sender: sender,
                text: text,
                class: sender === 'user' ? 'user-message' : 'system-message',
                showFeedback: sender === 'system',
                feedbackGiven: false,
                feedbackType: null
            }
        ];
        
        setTimeout(() => {
            const container = this.template.querySelector('.chat-container');
            if (container) {
                container.scrollTop = container.scrollHeight;
            }
        }, 100);
    }

    handleInputChange(event) {
        this.userInput = event.target.value;
    }

    handleSend() {
        const trimmedInput = this.userInput.trim();
        if (!trimmedInput) {
            return;
        }

        this.addMessage('user', trimmedInput);
        this.userInput = '';

        generateChatResponse({ contactId: this.recordId, chatQuestion: trimmedInput })
            .then(result => {
                this.addMessage('system', result);
            })
            .catch(error => {
                console.error('Error generating chat response: ', error);
                this.addMessage('system', 'Error: Unable to retrieve response.');
                this.showToast('Error', 'Unable to retrieve response', 'error');
            });
    }

    handleFeedback(event) {
        const messageId = event.currentTarget.dataset.messageid;
        const isPositive = event.currentTarget.dataset.feedback === 'positive';
        const message = this.messages.find(msg => msg.id === parseInt(messageId));
        
        if (message && !message.feedbackGiven) {
            // Update the UI to show feedback was given
            this.messages = this.messages.map(msg => {
                if (msg.id === parseInt(messageId)) {
                    return {
                        ...msg,
                        feedbackGiven: true,
                        feedbackType: isPositive ? 'positive' : 'negative'
                    };
                }
                return msg;
            });

            // Call Apex method to save feedback
            saveFeedback({
                contactId: this.recordId,
                messageId: messageId,
                response: message.text,
                isPositive: isPositive
            })
            .then(() => {
                this.showToast(
                    'Success',
                    `Feedback ${isPositive ? 'positive' : 'negative'} submitted successfully`,
                    'success'
                );
            })
            .catch(error => {
                console.error('Error saving feedback: ', error);
                this.showToast('Error', 'Unable to save feedback', 'error');
                // Revert the UI state on error
                this.messages = this.messages.map(msg => {
                    if (msg.id === parseInt(messageId)) {
                        return {
                            ...msg,
                            feedbackGiven: false,
                            feedbackType: null
                        };
                    }
                    return msg;
                });
            });
        }
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }

    get computedFeedbackClass() {
        return 'feedback-button';
    }
}