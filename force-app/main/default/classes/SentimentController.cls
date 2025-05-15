public with sharing class SentimentController { 
    @AuraEnabled(cacheable=true) 
    public static List<SentimentAggregate> getSentimentData() { 
        try { 
            List<AggregateResult> results = [
                SELECT 
                    CALENDAR_MONTH(Visit_Date__c) month, 
                    CALENDAR_YEAR(Visit_Date__c) year, 
                    Sentiment__c, 
                    COUNT(Id) recordCount 
                FROM 
                    Branch_Visit__c 
                WHERE 
                    Visit_Date__c != NULL 
                    AND Sentiment__c != NULL 
                GROUP BY 
                    CALENDAR_MONTH(Visit_Date__c), 
                    CALENDAR_YEAR(Visit_Date__c), 
                    Sentiment__c 
                ORDER BY 
                    CALENDAR_YEAR(Visit_Date__c), 
                    CALENDAR_MONTH(Visit_Date__c) 
                LIMIT 100
            ];

            Map<String, SentimentAggregate> aggregates = new Map<String, SentimentAggregate>();

            for (AggregateResult ar : results) {
                String monthYear = ar.get('month') + '/' + ar.get('year');
                if (!aggregates.containsKey(monthYear)) {
                    aggregates.put(monthYear, new SentimentAggregate(monthYear));
                }
                SentimentAggregate agg = aggregates.get(monthYear);
                String sentiment = (String) ar.get('Sentiment__c');
                Integer count = (Integer) ar.get('recordCount');

                if (sentiment.equalsIgnoreCase('Positive')) {
                    agg.positiveCount = count;
                } else if (sentiment.equalsIgnoreCase('Negative')) {
                    agg.negativeCount = count;
                } else if (sentiment.equalsIgnoreCase('Mixed')) {
                    agg.mixedCount = count;
                }
            }

            return aggregates.values();
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving sentiment data: ' + e.getMessage());
        }
    }

    public class SentimentAggregate {
        @AuraEnabled public String monthYear;
        @AuraEnabled public Integer positiveCount = 0;
        @AuraEnabled public Integer negativeCount = 0;
        @AuraEnabled public Integer mixedCount = 0;

        public SentimentAggregate(String monthYear) {
            this.monthYear = monthYear;
        }
    }
}