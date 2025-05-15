import { LightningElement, track, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import getSentimentData from '@salesforce/apex/SentimentController.getSentimentData';

export default class SentimentRadarChart extends LightningElement {
    @track chart;
    @track isChartJsInitialized = false;

    // Wire Apex method to fetch sentiment data
    @wire(getSentimentData)
    wiredSentimentData({ error, data }) {
        if (data) {
            this.renderChart(data);
        } else if (error) {
            console.error('Error fetching sentiment data:', error);
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
                console.log('Chart.js loaded successfully');
            })
            .catch(error => {
                console.error('Error loading Chart.js:', error);
            });
    }

    // Render the chart with fetched data
    renderChart(data) {
        if (!this.isChartJsInitialized || !data) {
            return;
        }

        const canvas = this.template.querySelector('canvas');
        if (!canvas) {
            console.error('Canvas element not found');
            return;
        }

        const ctx = canvas.getContext('2d');
        if (this.chart) {
            this.chart.destroy(); // Destroy existing chart before re-rendering
        }

        const labels = data.map(item => item.monthYear);
        const positiveData = data.map(item => item.positiveCount);
        const negativeData = data.map(item => item.negativeCount);
        const mixedData = data.map(item => item.mixedCount);

        this.chart = new Chart(ctx, {
            type: 'radar',
            data: {
                labels: labels,
                datasets: [
                    {
                        label: 'Positive Sentiment',
                        data: positiveData,
                        backgroundColor: 'rgba(75, 192, 192, 0.2)',
                        borderColor: 'rgba(75, 192, 192, 1)',
                        borderWidth: 1
                    },
                    {
                        label: 'Negative Sentiment',
                        data: negativeData,
                        backgroundColor: 'rgba(255, 99, 132, 0.2)',
                        borderColor: 'rgba(255, 99, 132, 1)',
                        borderWidth: 1
                    },
                    {
                        label: 'Mixed Sentiment',
                        data: mixedData,
                        backgroundColor: 'rgba(255, 206, 86, 0.2)',
                        borderColor: 'rgba(255, 206, 86, 1)',
                        borderWidth: 1
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    r: {
                        beginAtZero: true,
                        suggestedMax: Math.max(...[...positiveData, ...negativeData, ...mixedData]) + 5
                    }
                },
                plugins: {
                    legend: {
                        position: 'top'
                    },
                    tooltip: {
                        callbacks: {
                            label: function (context) {
                                return context.dataset.label + ': ' + context.raw;
                            }
                        }
                    }
                }
            }
        });
    }
}