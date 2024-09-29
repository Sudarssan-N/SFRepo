public class LoanApplicationEmailSender {
    
    public static void sendLoanApplicationEmail(Id loanApplicationId) {
        // Fetch the Loan Application record for email purposes
        Loan_Application__c loanApp = [SELECT  Name, Email_ID__c FROM Loan_Application__c WHERE Id = :loanApplicationId];

        // Generate the PDF from the Visualforce page
        PageReference pdfPage = Page.Loan_Application_PDF_Converter; // This is your existing Visualforce page
        pdfPage.getParameters().put('id', loanApplicationId);  // Pass the Loan Application record ID
        Blob pdfBlob = pdfPage.getContentAsPDF();

        // Create the PDF as an attachment
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName('LoanApplication.pdf');
        attachment.setBody(pdfBlob);
        attachment.setContentType('application/pdf');

        // Create and configure the email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[]{loanApp.Email_ID__c});  // Assuming Email__c is the customer's email field
        email.setSubject('Your Loan Application PDF');
        email.setHtmlBody('Please find attached a PDF copy of your loan application.');
        email.setFileAttachments(new Messaging.EmailFileAttachment[]{attachment});

        // Send the email
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email});
    }
}
