public with sharing class csatController {
    @AuraEnabled(cacheable=true)
    public static List<Branch_Visit__c> getCSATData() {
        try {
            return [
                SELECT Visit_Date__c, CSAT__c
                FROM Branch_Visit__c
                WHERE CSAT__c != NULL AND Visit_Date__c != NULL
                ORDER BY Visit_Date__c ASC
                LIMIT 100
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving CSAT data: ' + e.getMessage());
        }
    }
}