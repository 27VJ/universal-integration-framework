/**
 * RequestBuilder — constructs HttpRequest from metadata config.
 */
public with sharing class RequestBuilder {

    public HttpRequest buildRequest(
            Integration_Config__mdt config,
            Integration_Endpoint__mdt endpoint,
            SObject record,
            List<Integration_Field_Map__mdt> mappings) {

        HttpRequest req = new HttpRequest();
        String url = resolveEndpoint(endpoint, record);
        req.setEndpoint(url);
        req.setMethod(endpoint.HTTP_Method__c);
        req.setTimeout(config.Timeout__c != null ? (Integer) config.Timeout__c : 30000);

        if (String.isNotBlank(endpoint.Content_Type__c)) {
            req.setHeader('Content-Type', endpoint.Content_Type__c);
        }
        attachHeaders(req, endpoint);

        if (endpoint.HTTP_Method__c != 'GET' && endpoint.HTTP_Method__c != 'DELETE') {
            String payload = new PayloadTransformer().buildPayload(mappings, record);
            req.setBody(payload);
        }

        return req;
    }

    private String resolveEndpoint(Integration_Endpoint__mdt endpoint, SObject record) {
        String url = endpoint.Base_URL__c + endpoint.Path__c;
        Pattern p = Pattern.compile('\\{(\\w+)\\}');
        Matcher m = p.matcher(url);
        while (m.find()) {
            String fieldName = m.group(1);
            Object val = record.get(fieldName);
            url = url.replace('{' + fieldName + '}', val != null ? String.valueOf(val) : '');
        }
        return url;
    }

    private void attachHeaders(HttpRequest req, Integration_Endpoint__mdt endpoint) {
        if (String.isNotBlank(endpoint.Custom_Headers__c)) {
            Map<String, Object> headers =
                (Map<String, Object>) JSON.deserializeUntyped(endpoint.Custom_Headers__c);
            for (String key : headers.keySet()) {
                req.setHeader(key, String.valueOf(headers.get(key)));
            }
        }
    }
}
