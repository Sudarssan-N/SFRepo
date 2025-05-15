import { LightningElement, wire, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import getCSATData from '@salesforce/apex/CSATController.getCSATData';

export default class CsatTrendGraph extends LightningElement {
    @track chart;
    @track isChartJsInitialized = false;

    // Wire Apex method to fetch CSAT data
    @wire(getCSATData)
    wiredCSATData({ error, data }) {
        if (data) {
            this.renderChart(data);
        } else if (error) {
            console.error('Error fetching CSAT data:', error);
        }
    }

    // Load Chart.js library
    renderedCallback() {
        if (this.isChartJsInitialized) {
            return;
        }
        this.isChartJsInitialized = true;
        Promise.all([
            loadScript(this, 'https://cdn.jsdelivr.net/npm/chart.js')
        ])
            .then(() => {
                this.initializeChart();
            })
            .catch(error => {
                console.error('Error loading Chart.js:', error);
            });
    }

    // Initialize the chart canvas
    initializeChart() {
        const ctx = this.template.querySelector('canvas').getContext('2d');
        this.chart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: [],
                datasets: [{
                    label: 'CSAT Trend',
                    data: [],
                    borderColor: 'rgba(75, 192, 192, 1)',
                    backgroundColor: 'rgba(75, 192, 192, 0.2)',
                    fill: true,
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                scales: {
                    x: {
                        title: {
                            display: true,
                            text: 'Visit Date'
                        }
                    },
                    y: {
                        title: {
                            display: true,
                            text: 'CSAT Score'
                        },
                        beginAtZero: true
                    }
                }
            }
        });
    }

    // Render the chart with fetched data
    renderChart(data) {
        if (this.chart && data) {
            const labels = data.map(record => new Date(record.Visit_Date__c).toLocaleDateString());
            const csatValues = data.map(record => record.CSAT__c);

            this.chart.data.labels = labels;
            this.chart.data.datasets[0].data = csatValues;
            this.chart.update();
        }
    }
}