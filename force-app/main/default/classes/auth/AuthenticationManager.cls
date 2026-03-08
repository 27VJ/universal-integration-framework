public with sharing class AuthenticationManager {

    private static Map<String, CachedToken> tokenCache = new Map<String, CachedToken>();

    public HttpRequest authenticate(HttpRequest req, Integration_Auth__mdt auth) {
        if (auth == null) return req;
        
        switch on auth.Auth_Type__c {
            when 'Named_Credential' {
                return handleNamedCredential(req, auth.Named_Credential__c);
            }
            when 'OAuth2' {
                return handleOAuth2(req, auth);
            }
            when 'API_Key' {
                return handleApiKey(req, auth);
            }
            when 'Basic' {
                return handleBasicAuth(req, auth);
            }
            when else {
                throw new IntegrationException('Unsupported auth type: ' + auth.Auth_Type__c);
            }
        }
    }

    private HttpRequest handleNamedCredential(HttpRequest req, String credName) {
        String endpoint = req.getEndpoint();
        // Just extract path and query params, drop the original domain
        Url u = new Url(endpoint);
        String pathAndQuery = u.getPath() + (String.isNotBlank(u.getQuery()) ? '?' + u.getQuery() : '');
        req.setEndpoint('callout:' + credName + pathAndQuery);
        return req;
    }

    private HttpRequest handleOAuth2(HttpRequest req, Integration_Auth__mdt auth) {
        String token = getCachedToken(auth.DeveloperName);
        if (token == null) {
            token = requestNewToken(auth);
            cacheToken(auth.DeveloperName, token, auth.Token_Cache_Seconds__c);
        }
        req.setHeader('Authorization', 'Bearer ' + token);
        return req;
    }

    private HttpRequest handleApiKey(HttpRequest req, Integration_Auth__mdt auth) {
        String headerName = String.isNotBlank(auth.Auth_Header_Name__c) ? auth.Auth_Header_Name__c : 'X-API-Key';
        // Use placeholder for secrets retrieval
        String apiKey = IntegrationSecrets.getSecret(auth.Client_Id_Field__c); // Using client id field to hold the API key name mapping
        req.setHeader(headerName, apiKey);
        return req;
    }

    private HttpRequest handleBasicAuth(HttpRequest req, Integration_Auth__mdt auth) {
        String username = IntegrationSecrets.getSecret(auth.Client_Id_Field__c);
        String password = IntegrationSecrets.getSecret(auth.Client_Secret_Field__c);
        String credentials = EncodingUtil.base64Encode(Blob.valueOf(username + ':' + password));
        req.setHeader('Authorization', 'Basic ' + credentials);
        return req;
    }

    private String requestNewToken(Integration_Auth__mdt auth) {
        HttpRequest tokenReq = new HttpRequest();
        tokenReq.setEndpoint(auth.Token_Endpoint__c);
        tokenReq.setMethod('POST');
        tokenReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        
        String clientId = IntegrationSecrets.getSecret(auth.Client_Id_Field__c);
        String clientSecret = IntegrationSecrets.getSecret(auth.Client_Secret_Field__c);
        
        String body = 'grant_type=client_credentials&client_id=' + EncodingUtil.urlEncode(clientId, 'UTF-8') 
                      + '&client_secret=' + EncodingUtil.urlEncode(clientSecret, 'UTF-8');
                      
        if (String.isNotBlank(auth.Scope__c)) {
            body += '&scope=' + EncodingUtil.urlEncode(auth.Scope__c, 'UTF-8');
        }
        
        tokenReq.setBody(body);

        HttpResponse resp = new Http().send(tokenReq);
        if (resp.getStatusCode() == 200) {
            Map<String, Object> respBody = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
            return (String) respBody.get('access_token');
        }
        throw new IntegrationException('OAuth2 token request failed: ' + resp.getBody());
    }

    private String getCachedToken(String key) {
        if (tokenCache.containsKey(key)) {
            CachedToken ct = tokenCache.get(key);
            if (ct.expiresAt > System.currentTimeMillis()) {
                return ct.token;
            }
            tokenCache.remove(key);
        }
        return null;
    }

    private void cacheToken(String key, String token, Decimal cacheSecs) {
        CachedToken ct = new CachedToken();
        ct.token = token;
        ct.expiresAt = System.currentTimeMillis() + (Long) (cacheSecs != null ? cacheSecs * 1000 : 3600000);
        tokenCache.put(key, ct);
    }

    private class CachedToken {
        public String token;
        public Long expiresAt;
    }
}
