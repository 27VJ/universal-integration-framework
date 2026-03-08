/**
 * IntegrationWebhookResource — REST endpoint for inbound webhooks.
 */
@RestResource(urlMapping='/integration/webhook/*')
global with sharing class IntegrationWebhookResource {

    @HttpPost
    global static void handlePost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            String configName = req.requestURI.substringAfterLast('/');
            WebhookAuthenticator.verify(req, configName);

            String body = req.requestBody.toString();
            Map<String, Object> payload =
                (Map<String, Object>) JSON.deserializeUntyped(body);

            // Process synchronously
            InboundProcessor processor = new InboundProcessor();
            InboundResult result = processor.process(configName, payload);

            res.statusCode = result.isSuccess ? 200 : 422;
            res.responseBody = Blob.valueOf(JSON.serialize(result));

        } catch (Exception ex) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(
                JSON.serialize(new Map<String, String>{ 'error' => ex.getMessage() }));
        }
    }
}
