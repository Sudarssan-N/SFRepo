public class SSEEventController {

    @AuraEnabled(cacheable=false)
    public static String getEventData() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://llama-upright-possibly.ngrok-free.app/subscribe');  // Your Spring Boot endpoint
        req.setMethod('GET');
        
        // Optionally, add headers here if needed
        // req.setHeader('Authorization', 'Bearer YOUR_ACCESS_TOKEN');
        
        Http http = new Http();
        HttpResponse res = http.send(req);

        // Check if the response was successful
        if (res.getStatusCode() == 200) {
            return res.getBody();  // Return the response body (event data)
        } else {
            throw new AuraHandledException('Failed to retrieve data: ' + res.getStatus());
        }
    }
}
