public with sharing class CustomerSummaryControllerGemini {

    @AuraEnabled(cacheable=true)
    public static String generateCustomerSummary(Id contactId) {
        try {
            // Fetch Contact details
            Contact contact = [SELECT Name FROM Contact WHERE Id = :contactId];

            // Fetch related Ticket__c records
            List<Ticket__c> tickets = [
                SELECT Subject__c, Status__c, Created_Date__c
                FROM Ticket__c
                WHERE Contact__c = :contactId
            ];

            // Fetch related Email__c records
            List<Email__c> emails = [
                SELECT Subject__c, Direction__c, Sent_Date__c
                FROM Email__c
                WHERE Contact__c = :contactId
            ];

            // Fetch related Branch_Visit__c records
            List<Branch_Visit__c> branchVisits = [
                SELECT Branch_Name__c, Visit_Reason__c, Visit_Date__c
                FROM Branch_Visit__c
                WHERE Contact__c = :contactId
            ];

            // Build base prompts
            String concisePrompt = 'Generate a concise narrative summary (max 200 words) of the customer\'s recent activities and interactions without headings. Highlight key insights and actionable items.\n\n';
            String fullPrompt = 'Provide a detailed breakdown of the customer\'s interactions, including unresolved tickets, recent emails, and branch visits.\n\n';
            String conversationStarterPrompt = 'Provide three conversation starters based on the customer data below. The conversation starters should be tailored to the customer\'s data and actionable for the banker and one liner.\n\n';

            // Build a variable to hold customer context data for the actionable recommendations prompt
            String customerContext = '';

            // Append ticket data to prompts and customerContext
            for (Ticket__c ticket : tickets) {
                String ticketInfo = '- Ticket: ' + ticket.Subject__c + ' (' + ticket.Status__c + ', Created On: ' + String.valueOf(ticket.Created_Date__c) + ')\n';
                concisePrompt += ticketInfo;
                fullPrompt += ticketInfo;
                conversationStarterPrompt += ticketInfo;
                customerContext += ticketInfo;
            }

            // Append email data to prompts and customerContext
            for (Email__c email : emails) {
                String emailInfo = '- Email: ' + email.Subject__c + ' (Direction: ' + email.Direction__c + ', Sent On: ' + String.valueOf(email.Sent_Date__c) + ')\n';
                concisePrompt += emailInfo;
                fullPrompt += emailInfo;
                conversationStarterPrompt += emailInfo;
                customerContext += emailInfo;
            }

            // Append branch visit data to prompts and customerContext
            for (Branch_Visit__c visit : branchVisits) {
                String visitInfo = '- Branch Visit: ' + visit.Branch_Name__c + ' (Reason: ' + visit.Visit_Reason__c + ', Visit Date: ' + String.valueOf(visit.Visit_Date__c) + ')\n';
                concisePrompt += visitInfo;
                fullPrompt += visitInfo;
                conversationStarterPrompt += visitInfo;
                customerContext += visitInfo;
            }

            // Add a predictive query at the end of the concise prompt
            concisePrompt += '\nBased on the above interactions, predict the customer satisfaction score (on a scale of 1 to 10) and include it at the end of the summary.';

            // Build an actionable recommendations prompt that includes the customer context and the allowed actions list
            String actionablePrompt = 'Based on the following customer interactions:\n' + customerContext +
                    '\nProvide actionable insights and recommendations on what the customer might need next. ' +
                    'Return a JSON object with an "actions" key that is an array of objects. Each object should have a "label" (the text for the button) and an "action" (a unique identifier) property. ' +
                    'The allowed actions are only the following 10: \n' +
                    '1. scheduleAppointment\n' +
                    '2. createReferral\n' +
                    '3. respondToEmail\n' +
                    '4. loanOptions\n' +
                    '5. followUpAppointment\n' +
                    '6. otherReferral\n' +
                    '7. marketingCampaign\n' +
                    '8. productInfo\n' +
                    '9. serviceReview\n' +
                    '10. accountUpdate\n' +
                    'Output only the JSON without any additional commentary.';

            // Call Gemini API for each prompt
            String conciseSummary         = callGeminiAPI(concisePrompt);
            String fullSummary          = callGeminiAPI(fullPrompt);
            String conversationStarters   = callGeminiAPI(conversationStarterPrompt);
            //String actionableRecommendations = callGeminiAPI(actionablePrompt);

            // Format the responses
            conciseSummary         = formatPlainText(conciseSummary);
            fullSummary          = formatPlainText(fullSummary);
            conversationStarters   = formatPlainText(conversationStarters);
            //actionableRecommendations = formatPlainText(actionableRecommendations);

            // Convert conversation starters into a list (split by newline)
            List<String> conversationStarterList = conversationStarters.split('\n');

            // Build and return the JSON response
            Map<String, Object> result = new Map<String, Object>();
            result.put('conciseSummary', conciseSummary);
            result.put('fullSummary', fullSummary);
            result.put('conversationPrompts', conversationStarterList);
            //result.put('actionableRecommendations', actionableRecommendations);

            return JSON.serialize(result);

        } catch (Exception e) {
            throw new AuraHandledException('Error generating summary: ' + e.getMessage());
        }
    }

    // Helper method to call the Gemini API
    private static String callGeminiAPI(String prompt) {
        String geminiApiKey = 'AIzaSyDlNwXOIho38m0WimY_xmnG4gGM7qc9Qck'; // Replace with your actual Gemini API key
        String endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint + '?key=' + geminiApiKey);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        // Structure the request for Gemini API
        Map<String, Object> contentPart = new Map<String, Object>{
            'text' => prompt
        };

        List<Map<String, Object>> contents = new List<Map<String, Object>>{
            new Map<String, Object>{
                'parts' => new List<Map<String, Object>>{contentPart}
            }
        };

        Map<String, Object> requestBody = new Map<String, Object>{
            'contents' => contents
        };
        req.setBody(JSON.serialize(requestBody));
        req.setTimeout(120000); // Extended timeout for Gemini API

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new CalloutException('Gemini API call failed: ' + res.getBody());
        }

        // Deserialize and parse the response for Gemini API
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return extractContentFromGeminiResponse(result);
    }


    private static String extractContentFromGeminiResponse(Map<String, Object> responseMap) {
        if (responseMap.containsKey('candidates')) {
            List<Object> candidates = (List<Object>)responseMap.get('candidates');
            if (!candidates.isEmpty()) {
                Map<String, Object> firstCandidate = (Map<String, Object>)candidates[0];
                if (firstCandidate.containsKey('content')) {
                    Map<String, Object> content = (Map<String, Object>)firstCandidate.get('content');
                    if (content.containsKey('parts')) {
                        List<Object> parts = (List<Object>)content.get('parts');
                        if (!parts.isEmpty()) {
                            Map<String, Object> firstPart = (Map<String, Object>)parts[0];
                            if (firstPart.containsKey('text')) {
                                return (String)firstPart.get('text');
                            }
                        }
                    }
                }
            }
        }
        return 'No content found in Gemini response.';
    }


    // Helper method for formatting the plain text output
    private static String formatPlainText(String input) {
        // Remove formatting artifacts and trim spaces
        return input.replaceAll('\\*\\*', '').trim();
    }
}