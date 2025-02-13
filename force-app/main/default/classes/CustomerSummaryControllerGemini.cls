public with sharing class CustomerSummaryControllerGemini {

    // Maximum number of retry attempts
    private static final Integer MAX_RETRIES = 3;
    // Wait time between retries in milliseconds (5 seconds)
    private static final Integer RETRY_WAIT_TIME = 5000;
    // Maximum total wait time in milliseconds (30 seconds)
    private static final Integer MAX_TOTAL_WAIT_TIME = 30000;

    // Gemini API Key - Replace with your actual API key (consider using Custom Metadata or Named Credentials for security)
    private static final String geminiApiKey = 'AIzaSyDlNwXOIho38m0WimY_xmnG4gGM7qc9Qck'; // Replace with your actual API key

    @AuraEnabled(cacheable=true)
    public static String getContactSummary(String customerName) {
        try {
            String customerData = aggregateCustomerData(customerName);

            // Create the summary prompt
            String prompt = 'Please provide a brief customer summary of the following interactions in this exact format:\n\n' +
    'Brief overview of customer situation\n\n' +
    '1. **Urgent Matters**:\n' +
    '- list urgent items\n\n' +
    '2. **Pending Actions**:\n' +
    '- list pending items\n\n' +
    '3. **Significant Changes**:\n' +
    '- list significant changes\n\n' +
    'Use the following data:\n\n' +
    customerData;


            String summary = callGeminiAPIWithRetry(prompt);
            System.debug(summary);

            // Ensure we have a valid summary before returning
            if (String.isBlank(summary)) {
                summary = 'Unable to generate summary. Please review the raw data.';
            }

            // Create and serialize the response
            Map<String, Object> response = new Map<String, Object>{
                'summary_text' => summary,
                'raw_data' => parseCustomerData(customerData)
            };

            System.debug('Response Map: ' + response);
            return JSON.serialize(new Map<String, Object>{
                'summary_text' => summary.replace('\n', '<br>'),
                'raw_data' => parseCustomerData(customerData)
            });

        } catch (Exception e) {
            System.debug('Error in getCustomerSummary: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Error processing customer summary: ' + e.getMessage());
        }
    }

    private static String callGeminiAPIWithRetry(String prompt) {
        Integer attempts = 0;
        Long startTime = System.currentTimeMillis();

        while (attempts < MAX_RETRIES) {
            try {
                if (System.currentTimeMillis() - startTime > MAX_TOTAL_WAIT_TIME) {
                    throw new CalloutException('Maximum wait time exceeded');
                }

                String result = callGeminiAPI(prompt);
                if (String.isNotBlank(result)) {
                    return result;
                }
            } catch (CalloutException e) {
                attempts++;
                if (e.getMessage().contains('rate limit') && attempts < MAX_RETRIES) {
                    pauseExecution(RETRY_WAIT_TIME);
                    continue;
                }
                throw e;
            }
            attempts++;
        }

        return 'Summary generation failed after ' + MAX_RETRIES + ' attempts. Please try again.';
    }

    private static String callGeminiAPI(String prompt) {
        String endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent'; // Gemini 1.5 Pro Endpoint

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint + '?key=' + geminiApiKey); // API Key as query parameter
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
        req.setTimeout(10000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        System.debug('Gemini API Response Status: ' + res.getStatusCode());
        System.debug('Gemini API Response Body: ' + res.getBody());

        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            return extractGeneratedTextFromGemini(responseMap);
        } else {
            throw new CalloutException('Gemini API call failed: ' + res.getBody());
        }
    }

    private static String extractGeneratedTextFromGemini(Map<String, Object> responseMap) {
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
                                String textContent = ((String)firstPart.get('text')).trim();
                                return cleanUpSummary(textContent);
                            }
                        }
                    }
                }
            }
        }
        throw new CalloutException('Invalid Gemini response format: ' + JSON.serialize(responseMap));
    }


    private static String aggregateCustomerData(String customerName) {
        List<String> ticketDetails = new List<String>();
        List<String> emailDetails = new List<String>();
        List<String> visitDetails = new List<String>();

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

        Map<String, Object> data = new Map<String, Object>{
            'customer_info' => new Map<String, Object>{
                'name' => customer.Name,
                'email' => customer.Email,
                'mailing address' => customer.MailingAddress,
                'mobile phone' => customer.MobilePhone,
                'loan amount' => customer.Loan_Amount__c,
                'account ID' => customer.AccountId
            },
            'tickets' => ticketDetails,
            'emails' => emailDetails,
            'branch_visits' => visitDetails
        };
        return JSON.serialize(data);
    }



    @AuraEnabled
public static String generateFollowUpEmail(String customerName) {
    try {
        System.debug('Starting generateFollowUpEmail for customer: ' + customerName);

        // Aggregate the customer data
        String customerData = aggregateCustomerData(customerName);
        System.debug('Aggregated customer data: ' + customerData);

        // Create the email generation prompt
        String prompt = 'Draft a professional follow-up email based on the following customer data:\n\n' +
                       customerData + '\n\n' +
                       'Format the email exactly as follows:\n\n' +
                       'Subject: [Brief, relevant subject line]\n\n' +
                       'Dear [Name],\n\n' +
                       '[Email body with:\n' +
                       '- Reference to recent interactions\n' +
                       '- Current situation summary\n' +
                       '- Relevant recommendations\n' +
                       '- Clear next steps]\n\n' +
                       'Best regards,\n' +
                       '[Company Name] Team';

        System.debug('Generated prompt for Gemini: ' + prompt);

        // Call Gemini API with retry mechanism
        String emailContent = callGeminiAPIWithRetry(prompt);
        System.debug('Received email content from Gemini: ' + emailContent);

        // Validate email content
        if (String.isBlank(emailContent)) {
            System.debug('Error: Generated email content is blank');
            throw new CalloutException('Email generation failed. Please try again.');
        }

        // Clean up and format the email content
        String cleanedContent = cleanupEmailContent(emailContent);
        System.debug('Cleaned email content: ' + cleanedContent);

        // Create response map
        Map<String, Object> response = new Map<String, Object>{
            'email_content' => cleanedContent,
            'raw_data' => parseCustomerData(customerData)
        };

        System.debug('Final response map: ' + response);
        String serializedResponse = JSON.serialize(response);
        System.debug('Serialized response: ' + serializedResponse);

        return serializedResponse;

    } catch (Exception e) {
        String errorMsg = 'Error in generateFollowUpEmail: ' + e.getMessage() + '\n' + e.getStackTraceString();
        System.debug(LoggingLevel.ERROR, errorMsg);
        throw new AuraHandledException('Error generating follow-up email: ' + e.getMessage());
    }
}

private static String cleanupEmailContent(String content) {
    System.debug('Starting email content cleanup. Original content: ' + content);

    try {
        // First, standardize line breaks
        content = content.replaceAll('\r\n', '\n')
                        .replaceAll('\r', '\n');

        // Remove any extra blank lines
        content = content.replaceAll('(?m)^[ \t]*\r?\n', '');

        // Replace markdown formatting if present
        content = content.replaceAll('\\*\\*', '')
                        .replaceAll('__', '');

        // Ensure proper spacing around sections
        content = content.replaceAll('(?m)^Subject:', '\nSubject:')
                        .replaceAll('(?m)^Dear', '\nDear')
                        .replaceAll('(?m)^Best regards,', '\nBest regards,');

        // Convert line breaks for HTML display
        String finalContent = content.replace('\n', '<br>');

        System.debug('Completed email content cleanup. Final content: ' + finalContent);
        return finalContent;

    } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, 'Error in cleanupEmailContent: ' + e.getMessage() + '\n' + e.getStackTraceString());
        throw e;
    }
}


    private static String cleanUpSummary(String content) {
    // First, let's standardize the line breaks
    content = content.replaceAll('\r\n', '\n')
                    .replaceAll('\r', '\n');

    // Replace markdown headers with our custom format
    content = content.replaceAll('###', '')
                    .replaceAll('\\*\\*', '');  // Remove all ** markers

    // Add our own section markers
    content = content.replaceAll('(?m)^1\\. Urgent Matters:', '1. **Urgent Matters**:')
                    .replaceAll('(?m)^2\\. Pending Actions:', '2. **Pending Actions**:')
                    .replaceAll('(?m)^3\\. Significant Changes:', '3. **Significant Changes**:');

    return content;
}


    private static void pauseExecution(Integer milliseconds) {
        Long waitTimeStart = System.currentTimeMillis();
        while (System.currentTimeMillis() - waitTimeStart < milliseconds) {
            // Busy wait loop
        }
    }

    private static Map<String, Object> parseCustomerData(String customerData) {
        try {
            return (Map<String, Object>)JSON.deserializeUntyped(customerData);
        } catch (Exception e) {
            System.debug('Error parsing customer data: ' + e.getMessage());
            return new Map<String, Object>{'error' => 'Invalid data format'};
        }
    }
}