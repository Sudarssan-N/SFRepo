import { LightningElement, track, wire, api } from 'lwc';
import getCustomerSummary from '@salesforce/apex/CustomerSummaryController.getCustomerSummary';
import { getRecord } from 'lightning/uiRecordApi';

const FIELDS = [
    'Customer.Name',
    'Customer.CustomerStatusType',
    'Customer.TotalLifeTimeValue'
];

export default class CustomerSummary extends LightningElement {
    @track selectedCustomerId;
    @track selectedCustomerName;
    @track summary;
    @track customerData;
    @track error;
    @track isLoading = false;
    @track customerStatus;
    @track totalLifeTimeValue;
    @api formattedSummary;

    get isButtonDisabled() {
        return !this.selectedCustomerName;
    }

    renderedCallback() {
        // Find the container for the customer summary
        const summaryContainer = this.template.querySelector('.customer-summary');

        // Safely inject HTML content if it exists
        if (summaryContainer && this.formattedSummary?.customerSummary) {
            summaryContainer.innerHTML = this.formattedSummary.customerSummary;
        }
    }

    // Handle customer selection from lightning-record-edit-form
    handleCustomerSelection(event) {
        // Check if we have a valid selection
        if (event.detail.value) {
            console.log('Customer selected:', event.detail);
            this.selectedCustomerId = event.detail.value;
            // Get the selected record's name
            const selectedInput = this.template.querySelector('lightning-input-field');
            this.selectedCustomerName = selectedInput ? selectedInput.value : null;
            console.log('Selected Customer Name:', this.selectedCustomerName);
            
            // Clear previous data
            this.clearData();
        }
    }

    clearData() {
        this.summary = null;
        this.customerData = null;
        this.error = null;
        console.log('Data cleared for new selection');
    }

    handleGenerateSummary() {
        console.log('Generate Summary clicked for:', this.selectedCustomerName);
        if (!this.selectedCustomerName) {
            this.error = 'Please select a customer first.';
            return;
        }
        this.loadCustomerSummary();
    }

    loadCustomerSummary() {
        this.isLoading = true;
        this.error = null;
    
        getCustomerSummary({ customerName: this.selectedCustomerName })
            .then(result => {
                const data = JSON.parse(result);
                
                if (data.summary_text) {
                    // Store the raw summary text
                    this.summary = data.summary_text;
                    // Parse the formatted summary sections
                    this.formattedSummary = this.parseSummary(this.summary);
                }
    
                if (data.raw_data) {
                    this.customerData = data.raw_data;
                    if (data.raw_data.customer_info) {
                        this.customerStatus = data.raw_data.customer_info.status;
                        this.totalLifeTimeValue = data.raw_data.customer_info.lifetime_value;
                    }
                }
            })
            .catch(error => {
                this.error = 'Error fetching customer summary: ' + 
                    (error.body?.message || error.message || 'Unknown error');
                this.summary = null;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    parseSummary(summaryText) {

        console.log(summaryText)
        const parsedSummary = {
            mainSummary: '',
            urgentMatters: [],
            pendingActions: [],
            significantChanges: [],
            overallSummary: ''
        };
    
        try {
            const lines = summaryText.split('<br>').map(line => line.trim()).filter(Boolean);
            let currentSection = null;
    
            lines.forEach(line => {
                // Remove all asterisks from the line
                const cleanLine = line.replace(/\*\*/g, '');
                
                // Main summary
                if (!parsedSummary.mainSummary && !line.includes('Urgent Matters') && 
                    !line.includes('Pending Actions') && !line.includes('Significant Changes')) {
                    parsedSummary.mainSummary = cleanLine;
                    return;
                }
    
                // Detect sections
                if (cleanLine.includes('1. Urgent Matters')) {
                    currentSection = 'urgentMatters';
                    return;
                } else if (cleanLine.includes('2. Pending Actions')) {
                    currentSection = 'pendingActions';
                    return;
                } else if (cleanLine.includes('3. Significant Changes')) {
                    currentSection = 'significantChanges';
                    return;
                }
    
                // Capture overall summary
                if (cleanLine.startsWith('Overall')) {
                    parsedSummary.overallSummary = cleanLine;
                    currentSection = null;
                    return;
                }
    
                // Add items to current section
                if (currentSection && cleanLine.trim().startsWith('-')) {
                    const item = cleanLine.replace(/^-\s*/, '').trim();
                    parsedSummary[currentSection].push(item);
                }
            });
    
        } catch (error) {
            console.error('Error parsing summary:', error);
        }
    
        return parsedSummary;
    }

    // Getter for formatted customer status
    get customerStatusBadgeClass() {
        if (!this.customerStatus) return 'slds-theme_default';
        switch (this.customerStatus.toLowerCase()) {
            case 'active':
                return 'slds-theme_success';
            case 'inactive':
                return 'slds-theme_warning';
            case 'suspended':
                return 'slds-theme_error';
            default:
                return 'slds-theme_default';
        }
    }

    // Getter for formatted customer status
get customerStatusBadgeClass() {
    if (!this.customerStatus) return 'slds-theme_default';
    switch (this.customerStatus.toLowerCase()) {
        case 'active':
            return 'slds-theme_success';
        case 'inactive':
            return 'slds-theme_warning';
        case 'suspended':
            return 'slds-theme_error';
        default:
            return 'slds-theme_default';
    }
}

// Getter for formatted lifetime value
get formattedLifetimeValue() {
    if (!this.totalLifeTimeValue) return 'N/A';
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD'
    }).format(this.totalLifeTimeValue);
}

    get formattedLifetimeValue() {
        return this.totalLifeTimeValue 
            ? new Intl.NumberFormat('en-US', { 
                style: 'currency', 
                currency: 'USD' 
              }).format(this.totalLifeTimeValue)
            : 'N/A';
    }

    @api
    refresh() {
        console.log('Refresh requested');
        if (this.selectedCustomerName) {
            this.loadCustomerSummary();
        }
    }
}