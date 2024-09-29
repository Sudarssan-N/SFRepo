

global class ResetCustomerSessions implements Schedulable {
    global void execute(SchedulableContext sc) {
        // Calculate the cutoff time (10 minutes ago)
        DateTime cutoffTime = System.now().addMinutes(-10);

        // Query active sessions older than 10 minutes
        List<Customer_Session__c> sessionsToReset = [
            SELECT Id, Session_Active__c
            FROM Customer_Session__c
            WHERE Session_Active__c = true
            AND Authenticated_Timestamp__c <= :cutoffTime
        ];

        // Deactivate the sessions
        for (Customer_Session__c session : sessionsToReset) {
            session.Session_Active__c = false;
        }

        if (!sessionsToReset.isEmpty()) {
            update sessionsToReset;
        }
    }
}
