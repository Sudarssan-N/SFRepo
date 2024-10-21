import { LightningElement, track } from 'lwc';

export default class SseListener extends LightningElement {
    @track messages = [];
    isListening = false;
    eventSource;

    get isNotListening() {
        return !this.isListening;
    }

    startListening() {
        console.log('Attempting to start listening to SSE');
        if (this.isListening) {
            console.warn('Already listening');
            return;
        }

        const sseUrl = 'https://llama-upright-possibly.ngrok-free.app/sse/random-events';
        this.eventSource = new EventSource(sseUrl);

        this.eventSource.onopen = () => {
            console.log('SSE connection opened');
            this.isListening = true;
        };

        this.eventSource.onmessage = (event) => {
            console.log('Received message:', event.data);
            const message = JSON.parse(event.data);
            this.messages = [message, ...this.messages];
        };

        this.eventSource.onerror = (error) => {
            console.error('SSE Error:', error);
            this.stopListening();
        };
    }

    stopListening() {
        console.log('Attempting to stop listening to SSE');
        if (this.eventSource) {
            this.eventSource.close();
            this.eventSource = null;
            console.log('SSE connection closed');
        }
        this.isListening = false;
    }

    disconnectedCallback() {
        this.stopListening();
    }
}
