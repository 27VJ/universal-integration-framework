public with sharing class core_IntegrationService {

    public static IntegrationResult executeOutboundIntegration(String configName, List<Id> recordIds) {
        // Just handle the first record for now for simplicity of this signature, 
        // real bulkification would return List<IntegrationResult>
        if (recordIds == null || recordIds.isEmpty()) return IntegrationResult.failure('No records provided');
        
        return execute(configName, recordIds[0]);
    }

    public static IntegrationResult execute(String configName, Id recordId) {
        IntegrationContext ctx = new IntegrationContext(configName, recordId);
        try {
            // 1. Load metadata
            Integration_Config__mdt config = IntegrationConfigProvider.getConfig(configName);
            List<Integration_Field_Map__mdt> mappings = IntegrationConfigProvider.getFieldMaps(configName, 'Outbound');
            Integration_Endpoint__mdt endpoint = IntegrationConfigProvider.getEndpoint(config.Endpoint__c);
            
            // 2. Query source record
            SObject record = IntegrationQueryBuilder.queryRecord(config.Source_Object__c, mappings, recordId);

            // 3. Build request
            HttpRequest req = new RequestBuilder().buildRequest(config, endpoint, record, mappings);

            // 4. Authenticate
            if (String.isNotBlank(config.Auth_Config__c) && config.Auth_Config__c != 'None') {
                Integration_Auth__mdt auth = IntegrationConfigProvider.getAuth(config.Auth_Config__c);
                if (auth != null) {
                    req = new AuthenticationManager().authenticate(req, auth);
                }
            }

            // 5. Execute callout
            Long startMs = System.currentTimeMillis();
            HttpResponse resp = new Http().send(req);
            Long elapsedMs = System.currentTimeMillis() - startMs;

            // 6. Parse response
            IntegrationResult result = new ResponseParser().parse(resp, mappings, config, elapsedMs);

            // 7. Log
            IntegrationLogger.log(ctx, req, resp, result, elapsedMs);

            // 8. Retry if needed (assuming RetryManager and ErrorHandler exist and handle this logic)
            if (!result.isSuccess && ErrorHandler.isRetryable(resp.getStatusCode())) {
                new RetryManager().scheduleRetry(ctx);
            }

            return result;

        } catch (Exception ex) {
            new ErrorHandler().handle(ctx, ex);
            return IntegrationResult.failure(ex.getMessage() + '\n' + ex.getStackTraceString());
        }
    }
}
