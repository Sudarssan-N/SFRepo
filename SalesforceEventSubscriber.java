import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.WebSocket;
import okhttp3.WebSocketListener;

public class SalesforceEventSubscriber extends WebSocketListener {
    private static final String SALESFORCE_URL = "https://your_instance.salesforce.com/cometd/53.0";
    private OkHttpClient client;

    public SalesforceEventSubscriber() {
        client = new OkHttpClient();
    }

    public void connect() {
        Request request = new Request.Builder().url(SALESFORCE_URL).build();
        WebSocket ws = client.newWebSocket(request, this);
    }

    @Override
    public void onMessage(WebSocket webSocket, String text) {
        // Process the message and publish via SSE
        new EventController().publishEvent(text);
    }

    @Override
    public void onFailure(WebSocket webSocket, Throwable t, Response response) {
        // Handle errors and reconnections
    }
}
