public with sharing class AccountDataController {
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getSecurityQuestionsAndAnswers(Id accountId) {
        
        Set<String> fieldSet = new Set<String>{
            'Id',
            'Security_Question_1__c',
            'Security_Answer_1__c',
            'Security_Question_2__c',
            'Security_Answer_2__c',
            'Security_Question_3__c',
            'Security_Answer_3__c'
            'Security_Question_4__c',
            'Security_Answer_4__c',
            'Security_Question_5__c',
            'Security_Answer_5__c'
            
        };
        
        // Query the Account record
        Account acc = [SELECT 
            Security_Question_1__c,
            Security_Answer_1__c,
            Security_Question_2__c,
            Security_Answer_2__c,
            Security_Question_3__c,
            Security_Answer_3__c,
            Security_Question_4__c,
            Security_Answer_4__c,
            Security_Question_5__c,
            Security_Answer_5__c
            
            FROM Account
            WHERE Id = :accountId
        ];

        // Enforce FLS
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.READABLE,
            new List<Account> { acc }
        );

        List<Account> sanitizedRecords = (List<Account>)decision.getRecords();
        if (sanitizedRecords.isEmpty()) {
            throw new AuraHandledException('You do not have access to the security questions and answers.');
        }
        acc = sanitizedRecords[0];

        // Prepare the data to return
        Map<String, String> dataMap = new Map<String, String>();
        dataMap.put('Security_Question_1__c', acc.Security_Question_1__c);
        dataMap.put('Security_Answer_1__c', acc.Security_Answer_1__c);
        dataMap.put('Security_Question_2__c', acc.Security_Question_2__c);
        dataMap.put('Security_Answer_2__c', acc.Security_Answer_2__c);
        dataMap.put('Security_Question_3__c', acc.Security_Question_3__c);
        dataMap.put('Security_Answer_3__c', acc.Security_Answer_3__c);
        dataMap.put('Security_Question_4__c', acc.Security_Question_4__c);
        dataMap.put('Security_Answer_4__c', acc.Security_Answer_4__c);
        dataMap.put('Security_Question_5__c', acc.Security_Question_5__c);
        dataMap.put('Security_Answer_5__c', acc.Security_Answer_5__c);
        

        return dataMap;
    }
}
