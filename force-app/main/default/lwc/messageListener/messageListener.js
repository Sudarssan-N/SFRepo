import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import userId from '@salesforce/user/Id';

export default class MessageListener extends LightningElement {
    @track messages = [];
    @track isConnected = false;
    eventSource;
    brokerUrl = 'https://sse-pub-sub-8edc987ae02d.herokuapp.com/api'; // Update with your deployed Spring Boot URL

    // Configuration
    @api 
    maxMessages = 50; // Maximum number of messages to show

    connectedCallback() {
        this.initializeConnection();
    }

    disconnectedCallback() {
        this.closeConnection();
    }

    initializeConnection() {
        // First register the client
        fetch(`${this.brokerUrl}/register?userId=${userId}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        })
        .then(response => {
            if (!response.ok) {
                throw new Error('Registration failed');
            }
            return response.text();
        })
        .then(() => {
            // After successful registration, establish SSE connection
            this.connectSSE();
        })
        .catch(error => {
            console.error('Registration error:', error);
            this.showToast('Error', 'Failed to register for messages', 'error');
            // Retry after 5 seconds
            setTimeout(() => this.initializeConnection(), 5000);
        });
    }

    connectSSE() {
        this.closeConnection(); // Close any existing connection
        
        this.eventSource = new EventSource(`${this.brokerUrl}/stream?userId=${userId}`);
        
        this.eventSource.onopen = () => {
            this.isConnected = true;
            this.showToast('Success', 'Connected to message service', 'success');
        };

        this.eventSource.onmessage = (event) => {
            try {
                const message = JSON.parse(event.data);
                this.handleNewMessage(message);
            } catch (error) {
                console.error('Message parsing error:', error);
            }
        };

        this.eventSource.onerror = (error) => {
            console.error('SSE Error:', error);
            this.isConnected = false;
            this.closeConnection();
            // Retry connection after 5 seconds
            setTimeout(() => this.connectSSE(), 5000);
        };
    }

    handleNewMessage(message) {
        // Add new message to the start of the array
        this.messages = [message, ...this.messages.slice(0, this.maxMessages - 1)];
        
        // Show notification for new message
        this.showToast('New Message', message.content, 'info');
    }

    closeConnection() {
        if (this.eventSource) {
            this.eventSource.close();
            this.eventSource = null;
            this.isConnected = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    // Getters for template
    get connectionStatus() {
        return this.isConnected ? 'Connected' : 'Disconnecting...';
    }

    get connectionStatusClass() {
        return this.isConnected ? 'slds-text-color_success' : 'slds-text-color_error';
    }
}
