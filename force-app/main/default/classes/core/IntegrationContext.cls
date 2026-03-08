/**
 * IntegrationContext — carries all state through the integration lifecycle.
 */
public with sharing class IntegrationContext {

    public String configName;
    public String recordId;
    public Integration_Config__mdt config;
    public Integer httpStatusCode;
    public String requestPayload;
    public String lastError;
    public Integer retryCount = 0;

    public IntegrationContext(String configName, Id recordId) {
        this.configName = configName;
        this.recordId = recordId != null ? String.valueOf(recordId) : null;
        this.config = IntegrationConfigProvider.getConfig(configName);
    }
}
