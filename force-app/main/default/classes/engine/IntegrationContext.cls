public with sharing class IntegrationContext {
    public String configName { get; set; }
    public String configDevName { get; set; }
    public Id recordId { get; set; }
    public Integer retryCount { get; set; }
    
    // Properties used by Logger and RetryManager
    public Integration_Config__mdt config { get; set; }
    public Integer httpStatusCode { get; set; }
    public String requestPayload { get; set; }
    public String lastError { get; set; }
    
    public IntegrationContext(String configName, Id recId) {
        this.configName = configName;
        this.configDevName = configName;
        this.recordId = recId;
        this.retryCount = 0;
    }
}
