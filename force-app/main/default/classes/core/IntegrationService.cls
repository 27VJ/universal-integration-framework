/**
 * IntegrationService — main orchestrator for the Universal Integration Framework.
 * Executes integrations synchronously, in bulk, or asynchronously.
 */
public with sharing class IntegrationService {

    public static IntegrationResult execute(String configName, Id recordId) {
        IntegrationContext ctx = new IntegrationContext(configName, recordId);
        try {
            // 1. Load metadata
            Integration_Config__mdt config = ctx.config;
            List<Integration_Field_Map__mdt> mappings =
                IntegrationConfigProvider.getFieldMaps(configName, 'Outbound');
            Integration_Endpoint__mdt endpoint =
                IntegrationConfigProvider.getEndpoint(config.Endpoint__c);
            Integration_Auth__mdt auth =
                IntegrationConfigProvider.getAuth(config.Auth_Config__c);

            // 2. Query source record (with child relationships for array mappings)
            SObject record = IntegrationQueryBuilder.queryRecord(
                config.Source_Object__c, mappings, recordId);

            // 3. Build request
            HttpRequest req = new RequestBuilder().buildRequest(config, endpoint, record, mappings);

            // 4. Authenticate
            req = new AuthenticationManager().authenticate(req, auth);

            // 5. Execute callout
            Long startMs = System.currentTimeMillis();
            HttpResponse resp = new Http().send(req);
            Long elapsedMs = System.currentTimeMillis() - startMs;

            ctx.httpStatusCode = resp.getStatusCode();
            ctx.requestPayload = req.getBody();

            // 6. Parse response
            IntegrationResult result =
                new ResponseParser().parse(resp, mappings, config, elapsedMs);

            // 7. Log
            IntegrationLogger.log(ctx, req, resp, result, elapsedMs);

            // 8. Retry if needed
            if (!result.isSuccess && ErrorHandler.isRetryable(resp.getStatusCode())) {
                new RetryManager().scheduleRetry(ctx);
            }

            return result;

        } catch (Exception ex) {
            ctx.lastError = ex.getMessage();
            new ErrorHandler().handle(ctx, ex);
            return IntegrationResult.failure(ex.getMessage());
        }
    }

    public static List<IntegrationResult> executeBulk(
            String configName, List<Id> recordIds) {
        List<IntegrationResult> results = new List<IntegrationResult>();
        for (Id recId : recordIds) {
            results.add(execute(configName, recId));
        }
        return results;
    }

    public static Id executeAsync(String configName, Id recordId) {
        return System.enqueueJob(
            new IntegrationQueueable(configName, new List<Id>{ recordId }));
    }
}
