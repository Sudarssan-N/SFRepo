trigger MyCustomObjectTrigger on MyCustomObject__c (after insert, after update) {
    List<MyCustomEvent__e> events = new List<MyCustomEvent__e>();
    
    for (MyCustomObject__c record : Trigger.new) {
        MyCustomEvent__e event = new MyCustomEvent__e();
        event.CustomField__c = record.CustomField__c; // Map your object fields to event fields
        events.add(event);
    }

    if (!events.isEmpty()) {
        EventBus.publish(events);
    }
}
