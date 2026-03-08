/**
 * IntegrationLogger — records all integration execution attempts.
 */
public with sharing class IntegrationLogger {

    public static void log(
            IntegrationContext ctx, HttpRequest req, HttpResponse resp,
            IntegrationResult result, Long elapsedMs) {
        Integration_Log__c logRecord = new Integration_Log__c(
            Integration_Config__c = ctx.configName,
            Record_Id__c = ctx.recordId,
            Request_Payload__c = truncate(req.getBody(), 131072),
            Response_Payload__c = truncate(resp.getBody(), 131072),
            HTTP_Status_Code__c = resp.getStatusCode(),
            Status__c = result.isSuccess ? 'Success' : 'Failed',
            Error_Message__c = result.errorMessage,
            Execution_Time_Ms__c = elapsedMs,
            Retry_Count__c = ctx.retryCount,
            Timestamp__c = DateTime.now(),
            Direction__c = 'Outbound'
        );
        insert logRecord;
    }

    public static void logError(IntegrationContext ctx, Exception ex) {
        Integration_Log__c logRecord = new Integration_Log__c(
            Integration_Config__c = ctx.configName,
            Record_Id__c = ctx.recordId,
            Status__c = 'Failed',
            Error_Message__c = ex.getMessage() + '\n' + ex.getStackTraceString(),
            Timestamp__c = DateTime.now(),
            Direction__c = 'Outbound'
        );
        insert logRecord;
    }

    public static void logInbound(String configName, String payload, String result) {
        Integration_Log__c logRecord = new Integration_Log__c(
            Integration_Config__c = configName,
            Request_Payload__c = truncate(payload, 131072),
            Response_Payload__c = truncate(result, 131072),
            Status__c = 'Success',
            Timestamp__c = DateTime.now(),
            Direction__c = 'Inbound'
        );
        insert logRecord;
    }

    public static void logBatchSummary(String configName, Integer success, Integer fail) {
        Integration_Log__c logRecord = new Integration_Log__c(
            Integration_Config__c = configName,
            Status__c = fail == 0 ? 'Success' : 'Failed',
            Error_Message__c = 'Batch complete: ' + success + ' succeeded, ' + fail + ' failed',
            Timestamp__c = DateTime.now(),
            Direction__c = 'Outbound'
        );
        insert logRecord;
    }

    public static void logFinalFailure(IntegrationContext ctx) {
        Integration_Log__c logRecord = new Integration_Log__c(
            Integration_Config__c = ctx.configName,
            Record_Id__c = ctx.recordId,
            Status__c = 'Failed',
            Error_Message__c = 'Max retries exhausted. Last error: ' + ctx.lastError,
            Retry_Count__c = ctx.retryCount,
            Timestamp__c = DateTime.now(),
            Direction__c = 'Outbound'
        );
        insert logRecord;
    }

    private static String truncate(String s, Integer maxLen) {
        if (s == null) return null;
        return s.length() > maxLen ? s.substring(0, maxLen) : s;
    }
}
