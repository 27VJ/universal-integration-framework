/**
 * RetryManager — schedules retries with exponential backoff.
 */
public with sharing class RetryManager {

    public void scheduleRetry(IntegrationContext ctx) {
        Integration_Config__mdt config = ctx.config;
        if (ctx.retryCount >= config.Max_Retries__c) {
            IntegrationLogger.logFinalFailure(ctx);
            return;
        }

        Integer backoffSeconds = calculateBackoff(
            ctx.retryCount, (Integer) config.Retry_Interval_Seconds__c);

        Integration_Queue__c queueItem = new Integration_Queue__c(
            Integration_Config__c = config.DeveloperName,
            Record_Id__c = ctx.recordId,
            Payload__c = ctx.requestPayload,
            Status__c = 'Pending',
            Retry_Count__c = ctx.retryCount + 1,
            Next_Retry_At__c = DateTime.now().addSeconds(backoffSeconds),
            Error_Message__c = ctx.lastError
        );
        insert queueItem;
    }

    public void processRetryQueue() {
        List<Integration_Queue__c> items = [
            SELECT Id, Integration_Config__c, Record_Id__c, Payload__c, Retry_Count__c
            FROM Integration_Queue__c
            WHERE Status__c = 'Pending' AND Next_Retry_At__c <= :DateTime.now()
            ORDER BY Priority__c ASC, Next_Retry_At__c ASC
            LIMIT 200
        ];
        for (Integration_Queue__c item : items) {
            item.Status__c = 'Processing';
        }
        update items;

        for (Integration_Queue__c item : items) {
            System.enqueueJob(new IntegrationQueueable(
                item.Integration_Config__c,
                new List<Id>{ (Id) item.Record_Id__c }));
        }
    }

    private Integer calculateBackoff(Integer retryCount, Integer baseInterval) {
        Integer backoff = (Integer) (baseInterval * Math.pow(2, retryCount));
        return Math.min(backoff, 3600);
    }
}
