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
            String conversationStarterPrompt = 'Provide three conversation starters based on the customer data below. The conversation starters should be tailored to the customer\'s data and actionable for the banker and one liner. Only 3 points and each points needs to be only one liner or two liner\n\n';
            String sentimentPrompt = 'Based on the customer data below, predict the customer\'s expected sentiment (e.g., Positive, Neutral, Negative, or a short descriptive phrase). Provide a brief explanation (1-2 sentences) for the prediction. This needs to be on whole context of customer and need to be under 50 words\n\n';

            // Build a variable to hold customer context data
            String customerContext = '';

            // Append ticket data to prompts and customerContext
            for (Ticket__c ticket : tickets) {
                String ticketInfo = '- Ticket: ' + ticket.Subject__c + ' (' + ticket.Status__c + ', Created On: ' + String.valueOf(ticket.Created_Date__c) + ')\n';
                concisePrompt += ticketInfo;
                fullPrompt += ticketInfo;
                conversationStarterPrompt += ticketInfo;
                sentimentPrompt += ticketInfo;
                customerContext += ticketInfo;
            }

            // Append email data to prompts and customerContext
            for (Email__c email : emails) {
                String emailInfo = '- Email: ' + email.Subject__c + ' (Direction: ' + email.Direction__c + ', Sent On: ' + String.valueOf(email.Sent_Date__c) + ')\n';
                concisePrompt += emailInfo;
                fullPrompt += emailInfo;
                conversationStarterPrompt += emailInfo;
                sentimentPrompt += emailInfo;
                customerContext += emailInfo;
            }

            // Append branch visit data to prompts and customerContext
            for (Branch_Visit__c visit : branchVisits) {
                String visitInfo = '- Branch Visit: ' + visit.Branch_Name__c + ' (Reason: ' + visit.Visit_Reason__c + ', Visit Date: ' + String.valueOf(visit.Visit_Date__c) + ')\n';
                concisePrompt += visitInfo;
                fullPrompt += visitInfo;
                conversationStarterPrompt += visitInfo;
                sentimentPrompt += visitInfo;
                customerContext += visitInfo;
            }

            // Add a predictive query at the end of the concise prompt
            concisePrompt += '\nBased on the above interactions, predict the customer satisfaction score (on a scale of 1 to 10) and include it at the end of the summary.The satisfaction score is assumed to be in the format "Customer satisfaction score: X/10"';

            // Call Gemini API for each prompt
            String conciseSummary = callGeminiAPI(concisePrompt);
            String fullSummary = callGeminiAPI(fullPrompt);
            String conversationStarters = callGeminiAPI(conversationStarterPrompt);
            String expectedSentiment = callGeminiAPI(sentimentPrompt);

            // Format the responses
            conciseSummary = formatPlainText(conciseSummary);
            fullSummary = formatPlainText(fullSummary);
            conversationStarters = formatPlainText(conversationStarters);
            expectedSentiment = formatPlainText(expectedSentiment);

            // Convert conversation starters into a list (split by newline)
            List<String> conversationStarterList = conversationStarters.split('\n');

            // Build and return the JSON response
            Map<String, Object> result = new Map<String, Object>();
            result.put('conciseSummary', conciseSummary);
            result.put('fullSummary', fullSummary);
            result.put('conversationPrompts', conversationStarterList);
            result.put('expectedSentiment', expectedSentiment);

            return JSON.serialize(result);

        } catch (Exception e) {
            throw new AuraHandledException('Error generating summary: ' + e.getMessage());
        }
    }

    // Helper method to call the Gemini API
    private static String callGeminiAPI(String prompt) {
        String geminiApiKey = 'AIzaSyBBX-AoymRmOD9Ek8FXLndQ_DEfGupw5Ig'; // Replace with your actual Gemini API key
        String endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

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