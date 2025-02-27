public with sharing class BankerController {
    @AuraEnabled(cacheable=true)
    public static List<Appointment__c> getAppointmentsForBanker() {
        Id bankerId = 'a08dM00000DFfZdQAL';
        return [
            SELECT Id,  Contact__c, Contact__r.Name, Reason_for_Visit__c, Appointment_Time__c, Location__c, Banker__c
            FROM Appointment__c
            //AND Appointment_Date_and_Time__c >= TODAY
            ORDER BY Appointment_Time__c ASC
        ];
    }
    
    @AuraEnabled
    public static Appointment__c createAppointment(Appointment__c newAppt) {
        insert newAppt;
        return newAppt;
    }
}