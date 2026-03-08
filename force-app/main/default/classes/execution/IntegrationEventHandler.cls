/**
 * IntegrationEventHandler — handles Platform Event subscriptions.
 */
public class IntegrationEventHandler {

    public static void handle(List<Integration_Event__e> events) {
        for (Integration_Event__e evt : events) {
            System.enqueueJob(new IntegrationQueueable(
                evt.Config_Name__c,
                new List<Id>{ (Id) evt.Record_Id__c }));
        }
    }
}
