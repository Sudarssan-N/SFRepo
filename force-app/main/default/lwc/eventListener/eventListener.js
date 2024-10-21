import { LightningElement, track } from 'lwc';
import getEventData from '@salesforce/apex/SSEEventController.getEventData';

export default class EventListener extends LightningElement {
    @track messages = [];  // Array to store event messages
    intervalId;  // ID for the interval timer

    // Start listening to events (fetch data every 5 seconds)
    startListening() {
        this.intervalId = setInterval(() => {
            this.fetchEventData();
        }, 5000);  // Fetch event data every 5 seconds
    }

    // Stop listening to events (clear the interval)
    stopListening() {
        clearInterval(this.intervalId);
    }

    // Fetch event data from Apex controller
    fetchEventData() {
        getEventData()
            .then(result => {
                const newMessage = {
                    id: this.messages.length + 1,
                    text: result  // Append the new event data to the message list
                };
                this.messages = [...this.messages, newMessage];
            })
            .catch(error => {
                console.error('Error fetching event data:', error);
            });
    }
}
