public class LoanApplicationPDFController {
    public Loan_Application__c loanApp { get; set; }
    
    public LoanApplicationPDFController() {
        // Fetch the record ID from the URL parameter (this will be passed to the VF page)
        String recordId = ApexPages.currentPage().getParameters().get('id');
        // Fetch the Loan Application record based on the record ID
        loanApp = [SELECT Customer__c, Customer_DOB__c, Customer_Income__c, Email_ID__c, Employment_Status__c, Loan_Amount__c, Loan_Type__c, Term_Length__c, Credit_Score__c,
                   FROM Loan_Application__c WHERE Id = :recordId];
    }
}
