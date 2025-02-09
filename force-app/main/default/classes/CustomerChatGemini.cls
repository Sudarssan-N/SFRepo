public with sharing class CustomerChatGemini {

    @AuraEnabled
    public static String getCustomerSummary(String customerName) {
        try {
            // Aggregate customer data
            String jsonData = aggregateCustomerData(customerName);

            // Call Google Gemini API for summarization
            String summary = callGoogleGeminiAPI(jsonData, 'You are a customer insights assistant. Provide a summary based on the following data:');

            return summary;

        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String generateFollowUpEmail(String customerName) {
        try {
            // Aggregate customer data
            String jsonData = aggregateCustomerData(customerName);

            // Call Google Gemini API to generate a follow-up email
            String emailContent = callGoogleGeminiAPI(jsonData, 'You are an assistant. Generate a professional follow-up email based on the following customer data:');

            return emailContent;

        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }

    private static String aggregateCustomerData(String customerName) {
        List<String> ticketDetails = new List<String>();
        List<String> emailDetails = new List<String>();
        List<String> visitDetails = new List<String>();

        // Fetch customer details
        Contact customer = [
            SELECT Name, Email, MailingAddress, MobilePhone, Loan_Amount__c, AccountId
            FROM Contact
            WHERE Name = :customerName
            LIMIT 1
        ];


        // Fetch ticket data
        List<Ticket__c> tickets = [
            SELECT Subject__c, Status__c, Created_Date__c
            FROM Ticket__c
            WHERE Contact__c = :customer.Id
        ];
        for (Ticket__c t : tickets) {
            ticketDetails.add('Ticket: ' + t.Subject__c + ' (' + t.Status__c + ') on ' + t.Created_Date__c?.format());
        }

        // Fetch email data
        List<Email__c> emails = [
            SELECT Subject__c, Sent_Date__c, Direction__c
            FROM Email__c
            WHERE Contact__c = :customer.Id
        ];
        for (Email__c e : emails) {
            emailDetails.add('Email: ' + e.Subject__c + ' (' + e.Direction__c + ') on ' + e.Sent_Date__c?.format());
        }

        // Fetch branch visit data
        List<Branch_Visit__c> visits = [
            SELECT Branch_Name__c, Visit_Reason__c, Visit_Date__c
            FROM Branch_Visit__c
            WHERE Contact__c = :customer.Id
        ];
        for (Branch_Visit__c v : visits) {
            visitDetails.add('Branch Visit: ' + v.Branch_Name__c + ' for ' + v.Visit_Reason__c + ' on ' + v.Visit_Date__c?.format());
        }

        // Construct JSON
        Map<String, Object> data = new Map<String, Object>{
            'customer_info' => new Map<String, Object>{
                'name' => customer.Name,
                'email' => customer.Email,
                'mailing_address' => customer.MailingAddress,
                'mobile_phone' => customer.MobilePhone,
                'loan_amount' => customer.Loan_Amount__c,
                'account_id' => customer.AccountId
            },
            'tickets' => ticketDetails,
            'emails' => emailDetails,
            'branch_visits' => visitDetails
        };
        return JSON.serializePretty(data);
    }

    private static String callGoogleGeminiAPI(String jsonPayload, String prompt) {
        String endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent'; // Google Gemini Pro Endpoint
        String apiKey = 'AIzaSyCleCuHTcmUJzxYAdGrS2QVyCTbavrXBDw'; // Replace with your actual Google Gemini API Key

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('X-Goog-Api-Key', apiKey); // API Key Header for Google Gemini


        // Prepare Google Gemini  Prompt - adapting the ChatGPT prompt
        String geminiPrompt = 'You are a customer relationship insights assistant for a bank. Analyze the following customer information to form meaningful insights. Specifically, identify:\n' +
                            '1. Any open issues or concerns the customer may have that need to be addressed urgently.\n' +
                            '2. Key information that a banker meeting this customer should know.\n' +
                            '3. The customer\'s recent interests or inquiries about bank products or services.\n' +
                            '4. Any notable patterns or behaviors that might help improve the relationship with the customer.\n\n' +
                            'Here is the customer data:\n' + jsonPayload;


        // Prepare the API request body for Google Gemini
        Map<String, Object> requestBody = new Map<String, Object>{
            'contents' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'parts' => new List<Map<String, String>>{
                        new Map<String, String>{'text' => geminiPrompt}
                    }
                }
            }
        };


        req.setBody(JSON.serialize(requestBody));

        // Make the HTTP callout
        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() == 200) {
            // Parse the response
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

            List<Object> candidates = (List<Object>) responseMap.get('candidates');
            if (candidates != null && !candidates.isEmpty()) {
                Map<String, Object> firstCandidate = (Map<String, Object>) candidates[0];
                Map<String, Object> content = (Map<String, Object>) firstCandidate.get('content');
                List<Object> parts = (List<Object>) content.get('parts');

                if (parts != null && !parts.isEmpty()) {
                    Map<String, Object> firstPart = (Map<String, Object>) parts[0];
                    String textContent = (String) firstPart.get('text');
                    return textContent;
                } else {
                    throw new CalloutException('No parts returned from Google Gemini API in content.');
                }

            } else {
                throw new CalloutException('No candidates returned from Google Gemini API.');
            }
        } else {
            throw new CalloutException('Error from Google Gemini API: ' + res.getBody());
        }
    }
}