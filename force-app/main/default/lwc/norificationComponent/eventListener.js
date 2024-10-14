import { LightningElement, track } from 'lwc';

export default class EventListener extends LightningElement {
    @track messages = [];  // List of messages from the server
    eventSource;

    // Method to connect to the SSE endpoint
    connectToSSE() {
        // Establish connection with the Spring Boot server
        this.eventSource = new EventSource('http://localhost:8080/subscribe');  // Replace with your Spring Boot URL

        // Listen for incoming messages from the server
        this.eventSource.onmessage = (event) => {
            const newMessage = {
                id: this.messages.length + 1,
                text: event.data  // Event data is the random message sent by the server
            };
            this.messages = [...this.messages, newMessage];  // Add new message to the list
        };

        // Error handling
        this.eventSource.onerror = (error) => {
            console.error('EventSource failed:', error);
        };
    }
}
