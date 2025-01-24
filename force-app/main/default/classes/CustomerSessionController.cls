public with sharing class CustomerSessionController {
    @AuraEnabled(cacheable=true)
    public static Boolean getActiveSession(Id accountId) {
        DateTime cutoffTime = System.now().addMinutes(-10);

        Customer_Session__c activeSession = [
            SELECT Id
            FROM Customer_Session__c
            WHERE Account__c = :accountId
            AND Session_Active__c = true
            AND Authenticated_Timestamp__c > :cutoffTime
            LIMIT 1
        ];

        return activeSession != null;
    }
}