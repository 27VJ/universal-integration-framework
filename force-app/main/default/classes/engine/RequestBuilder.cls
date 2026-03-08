public with sharing class RequestBuilder {

    public HttpRequest buildRequest(
            Integration_Config__mdt config,
            Integration_Endpoint__mdt endpoint,
            SObject record,
            List<Integration_Field_Map__mdt> mappings) {

        HttpRequest req = new HttpRequest();

        // Resolve URL with merge fields
        String url = resolveEndpoint(endpoint, record);
        req.setEndpoint(url);
        req.setMethod(endpoint.HTTP_Method__c);
        req.setTimeout(config.Timeout__c != null ? Integer.valueOf(config.Timeout__c) : 30000);

        // Content type
        if (String.isNotBlank(endpoint.Content_Type__c)) {
            req.setHeader('Content-Type', endpoint.Content_Type__c);
        }

        // Custom headers
        attachHeaders(req, endpoint);

        // Body (for POST/PUT/PATCH)
        if (endpoint.HTTP_Method__c != 'GET' && endpoint.HTTP_Method__c != 'DELETE') {
            String payload = new PayloadTransformer().buildPayload(mappings, record);
            req.setBody(payload);
        }

        return req;
    }

    private String resolveEndpoint(Integration_Endpoint__mdt endpoint, SObject record) {
        String url = endpoint.Base_URL__c;
        if (String.isNotBlank(endpoint.Path__c)) {
             url += endpoint.Path__c;
        }
        
        // Replace {mergeField} tokens with record values if a record was provided
        if (record != null) {
            Pattern p = Pattern.compile('\\{(\\w+)\\}');
            Matcher m = p.matcher(url);
            while (m.find()) {
                String fieldName = m.group(1);
                try {
                    Object val = record.get(fieldName);
                    url = url.replace('{' + fieldName + '}', val != null ? String.valueOf(val) : '');
                } catch (System.SObjectException ex) {
                    // Field not retrieved in query or invalid, leave blank
                    url = url.replace('{' + fieldName + '}', '');
                }
            }
        }
        
        // Append Query Parameters if defined
        if (String.isNotBlank(endpoint.Query_Parameters__c)) {
             Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(endpoint.Query_Parameters__c);
             List<String> queryStrings = new List<String>();
             for (String key : params.keySet()) {
                 queryStrings.add(key + '=' + EncodingUtil.urlEncode(String.valueOf(params.get(key)), 'UTF-8'));
             }
             if (!queryStrings.isEmpty()) {
                 url += (url.contains('?') ? '&' : '?') + String.join(queryStrings, '&');
             }
        }
        
        return url;
    }

    private void attachHeaders(HttpRequest req, Integration_Endpoint__mdt endpoint) {
        if (String.isNotBlank(endpoint.Custom_Headers__c)) {
            try {
                Map<String, Object> headers = (Map<String, Object>) JSON.deserializeUntyped(endpoint.Custom_Headers__c);
                for (String key : headers.keySet()) {
                    req.setHeader(key, String.valueOf(headers.get(key)));
                }
            } catch (Exception ex) {
                System.debug('Failed to parse Custom Headers JSON: ' + ex.getMessage());
            }
        }
    }
}
