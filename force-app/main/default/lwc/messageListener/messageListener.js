import { LightningElement, track } from 'lwc';

export default class MessageListener extends LightningElement {
    @track messages = [];
    @track connectionStatus = 'Disconnected';
    @track activeClients = 0;
    eventSource;
    maxRetries = 3;
    retryCount = 0;
    retryDelay = 5000;
    
    get serverUrl() {
        // Update this with your server URL
        return 'https://llama-upright-possibly.ngrok-free.app/events';
    }

    connectedCallback() {
        this.connectToEventSource();
    }

    disconnectedCallback() {
        this.cleanupConnection();
    }

    cleanupConnection() {
        if (this.eventSource) {
            this.eventSource.close();
            this.eventSource = null;
        }
    }

    async validateServerConnection() {
        try {
            // First check if server is available
            const response = await fetch(this.serverUrl.replace('/events', '/'));
            if (!response.ok) throw new Error('Server not available');
            return true;
        } catch (error) {
            console.error('Server validation failed:', error);
            return false;
        }
    }

    async connectToEventSource() {
        try {
            this.connectionStatus = 'Validating connection...';
            
            // Validate server first
            const isServerAvailable = await this.validateServerConnection();
            if (!isServerAvailable) {
                throw new Error('Server not available');
            }

            this.connectionStatus = 'Connecting...';
            console.log('Initializing SSE connection...');

            // Create EventSource with proper headers
            this.eventSource = new EventSource(this.serverUrl, {
                withCredentials: false
            });

            // Connection opened
            this.eventSource.onopen = () => {
                console.log('SSE connection opened');
                this.connectionStatus = 'Connected';
                this.retryCount = 0;
            };

            // Connected event
            this.eventSource.addEventListener('connected', (event) => {
                console.log('Connected event received');
                const data = JSON.parse(event.data);
                this.addMessage({
                    type: 'status',
                    message: data.message,
                    timestamp: new Date().toISOString()
                });
            });

            // Update event
            this.eventSource.addEventListener('update', (event) => {
                const data = JSON.parse(event.data);
                this.activeClients = data.activeClients;
                this.addMessage({
                    type: 'update',
                    message: data.message,
                    timestamp: data.timestamp,
                    activeClients: data.activeClients
                });
            });

            // Error handling
            this.eventSource.onerror = (error) => {
                console.error('SSE connection error:', error);
                this.handleError(error);
            };

        } catch (error) {
            console.error('Error in connectToEventSource:', error);
            this.handleError(error);
        }
    }

    handleError(error) {
        this.cleanupConnection();
        
        if (this.retryCount < this.maxRetries) {
            this.retryCount++;
            this.connectionStatus = `Connection error - Retry ${this.retryCount}/${this.maxRetries}`;
            
            setTimeout(() => {
                console.log(`Retrying connection (${this.retryCount}/${this.maxRetries})...`);
                this.connectToEventSource();
            }, this.retryDelay);
        } else {
            this.connectionStatus = 'Connection failed - Please refresh the page';
        }
    }

    addMessage(message) {
        this.messages = [...this.messages, message];
        if (this.messages.length > 10) {
            this.messages = this.messages.slice(-10);
        }
    }
}