public with sharing class ActiveSessionsController {
    @AuraEnabled(cacheable=true)
    public static List<Customer_Session__c> getActiveSessions() {
        // Get the current user's Id
        Id userId = UserInfo.getUserId();

        // Query active sessions created by the logged-in banker
        List<Customer_Session__c> sessions = [
            SELECT Id, Name, Account__c, Account__r.Name, Authenticated_Timestamp__c
            FROM Customer_Session__c
            WHERE CreatedById = :userId
            AND Session_Active__c = true
            ORDER BY Authenticated_Timestamp__c DESC
        ];

        return sessions;
    }

    @AuraEnabled
    public static void deleteSession(Id sessionId) {
        // Get the session record
        Customer_Session__c session = [
            SELECT Id, CreatedById
            FROM Customer_Session__c
            WHERE Id = :sessionId
            LIMIT 1
        ];

        // Ensure that the logged-in user is the creator of the session
        if (session.CreatedById != UserInfo.getUserId()) {
            throw new AuraHandledException('You do not have permission to delete this session.');
        }

        // Delete the session
        delete session;
    }
}
