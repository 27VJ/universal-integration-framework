/**
 * WebhookAuthenticator — verifies inbound webhook signatures.
 */
public with sharing class WebhookAuthenticator {

    public static void verify(RestRequest req, String configName) {
        Integration_Auth__mdt auth =
            IntegrationConfigProvider.getAuthByConfig(configName);

        if (auth == null || auth.Auth_Type__c == 'Named_Credential') return;

        switch on auth.Auth_Type__c {
            when 'Custom' {
                verifyHmac(req, auth);
            }
            when 'API_Key' {
                verifyApiKey(req, auth);
            }
        }
    }

    private static void verifyHmac(RestRequest req, Integration_Auth__mdt auth) {
        String signature = req.headers.get('X-Signature');
        String secret = IntegrationSecrets.getSecret(auth.Client_Secret_Field__c);
        String computedSig = EncodingUtil.convertToHex(
            Crypto.generateMac('HmacSHA256', req.requestBody, Blob.valueOf(secret)));
        if (signature != computedSig) {
            throw new IntegrationException('Invalid webhook signature');
        }
    }

    private static void verifyApiKey(RestRequest req, Integration_Auth__mdt auth) {
        String headerName = String.isNotBlank(auth.Auth_Header_Name__c)
            ? auth.Auth_Header_Name__c : 'X-API-Key';
        String providedKey = req.headers.get(headerName);
        String expectedKey = IntegrationSecrets.getSecret(auth.Client_Id_Field__c);
        if (providedKey != expectedKey) {
            throw new IntegrationException('Invalid API key');
        }
    }
}
