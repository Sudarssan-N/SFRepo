public with sharing class CustomerChatControllerGemini {

    @AuraEnabled(cacheable=false)
    public static String generateChatResponse(Id contactId, String chatQuestion) {
        try {
            // Query the Contact (for context)
            Contact contact = [SELECT Name FROM Contact WHERE Id = :contactId LIMIT 1];

            // Query related Ticket__c records
            List<Ticket__c> tickets = [
                SELECT Subject__c, Status__c, Created_Date__c
                FROM Ticket__c
                WHERE Contact__c = :contactId
            ];

            // Query related Email__c records
            List<Email__c> emails = [
                SELECT Subject__c, Direction__c, Sent_Date__c
                FROM Email__c
                WHERE Contact__c = :contactId
            ];

            // Query related Branch_Visit__c records
            List<Branch_Visit__c> branchVisits = [
                SELECT Branch_Name__c, Visit_Reason__c, Visit_Date__c
                FROM Branch_Visit__c
                WHERE Contact__c = :contactId
            ];

            // Build a customer context string from the data
            String customerContext = 'Customer Name: ' + contact.Name + '\n';

            for (Ticket__c t : tickets) {
                customerContext += '- Ticket: ' + t.Subject__c + ' (' + t.Status__c + ', Created On: ' + String.valueOf(t.Created_Date__c) + ')\n';
            }
            for (Email__c e : emails) {
                customerContext += '- Email: ' + e.Subject__c + ' (Direction: ' + e.Direction__c + ', Sent On: ' + String.valueOf(e.Sent_Date__c) + ')\n';
            }
            for (Branch_Visit__c bv : branchVisits) {
                customerContext += '- Branch Visit: ' + bv.Branch_Name__c + ' (Reason: ' + bv.Visit_Reason__c + ', Visit Date: ' + String.valueOf(bv.Visit_Date__c) + ')\n';
            }

            // Build the prompt for Gemini. We instruct it to answer based solely on the provided Salesforce data.
            String prompt = 'Below is the context of a customer from Salesforce:\n' + customerContext +
                '\nAnswer the following question based solely on the above customer data. Ensure that your response is accurate and does not include any hallucinations.\n\n' +
                'Question: ' + chatQuestion;

            // Call the Google Gemini API to get a response
            String chatResponse = callGoogleGeminiAPI(prompt);
            chatResponse = formatPlainText(chatResponse);
            return chatResponse;

        } catch (Exception e) {
            // Throw an exception that can be handled on the client side
            throw new AuraHandledException('Error generating chat response: ' + e.getMessage());
        }
    }

    // Helper method to call the Google Gemini API
    private static String callGoogleGeminiAPI(String prompt) {
        // IMPORTANT: In production, securely retrieve your API key rather than hardcoding it.
        String apiKey = 'AIzaSyDlNwXOIho38m0WimY_xmnG4gGM7qc9Qck'; // Replace with your actual Google Gemini API Key

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent'); // Google Gemini Pro Endpoint
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('X-Goog-Api-Key', apiKey); // API Key Header for Google Gemini

        // Build the request payload for Gemini API
        Map<String, Object> requestBody = new Map<String, Object>{
            'contents' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'parts' => new List<Map<String, String>>{
                        new Map<String, String>{'text' => prompt}
                    }
                }
            }
        };


        req.setBody(JSON.serialize(requestBody));
        req.setTimeout(120000); // Set timeout to 2 minutes

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new CalloutException('Google Gemini API call failed: ' + res.getBody());
        }

        // Parse the response from Google Gemini API
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
            }
        }
        return 'No content found in Google Gemini response.';
    }

    // Helper method to format the output text (e.g., remove unwanted markdown artifacts)
    private static String formatPlainText(String input) {
        return input.replaceAll('\\*\\*', '').trim();
    }


    // --- Removed API_KEY Constant -- Best practice is to not have API Key in Code ---
    // ---  Ensure you manage your API key securely (e.g., Custom Setting, Named Credential) ---

}