public class PDFEmailQueueable implements Queueable, Database.AllowsCallouts {
    
    private Id loanApplicationId;
    
    // Constructor to pass the Loan Application ID
    public PDFEmailQueueable(Id loanAppId) {
        this.loanApplicationId = loanAppId;
    }
    
    // Execute method that gets called asynchronously
    public void execute(QueueableContext context) {
        try {
            // Generate the PDF from the Visualforce page
            PageReference pdfPage = Page.Loan_Application_PDF_Converter;
            pdfPage.getParameters().put('id', loanApplicationId);
            Blob pdfBlob = pdfPage.getContentAsPDF();
            
            // Query the Loan Application to get customer email
            Loan_Application__c loanApp = [SELECT Customer_Name__c, Email__c FROM Loan_Application__c WHERE Id = :loanApplicationId LIMIT 1];

            // Create the email attachment
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName('LoanApplication.pdf');
            attachment.setBody(pdfBlob);
            attachment.setContentType('application/pdf');

            // Create and send the email
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[]{loanApp.Email__c});
            email.setSubject('Your Loan Application PDF');
            email.setHtmlBody('Dear ' + loanApp.Customer_Name__c + ',<br/><br/>Please find attached your loan application.');
            email.setFileAttachments(new Messaging.EmailFileAttachment[]{attachment});
            
            // Send the email
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email});
        } catch (Exception e) {
            // Handle exception (optional logging)
            System.debug('Error sending email: ' + e.getMessage());
        }
    }
}


trigger LoanApplicationTrigger on Loan_Application__c (after insert, after update) {
    for (Loan_Application__c loanApp : Trigger.new) {
        // Enqueue the asynchronous job to generate the PDF and send the email
        System.enqueueJob(new PDFEmailQueueable(loanApp.Id));
    }
}
