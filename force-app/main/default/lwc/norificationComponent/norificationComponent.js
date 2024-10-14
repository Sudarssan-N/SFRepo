import { LightningElement } from 'lwc';

export default class NotificationComponent extends LightningElement {
    notifications = [];

    connectedCallback() {
        // Set up EventSource connection to your server endpoint
        const eventSource = new EventSource('/events');

        eventSource.onmessage = (event) => {
            const notification = event.data;
            this.notifications = [...this.notifications, notification];
        };

        eventSource.onerror = (error) => {
            console.error('Error with EventSource:', error);
        };
    }
}
