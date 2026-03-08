public with sharing class IntegrationResult {
    @AuraEnabled public Boolean isSuccess { get; set; }
    @AuraEnabled public Integer statusCode { get; set; }
    @AuraEnabled public String responseBody { get; set; }
    @AuraEnabled public String errorMessage { get; set; }
    @AuraEnabled public Long executionTimeMs { get; set; }
    @AuraEnabled public Map<String, Object> parsedResponse { get; set; }
    @AuraEnabled public List<SObject> parsedRecords { get; set; }

    public IntegrationResult() {
        this.isSuccess = false;
        this.parsedResponse = new Map<String, Object>();
        this.parsedRecords = new List<SObject>();
    }

    public static IntegrationResult failure(String errorMsg) {
        IntegrationResult res = new IntegrationResult();
        res.isSuccess = false;
        res.errorMessage = errorMsg;
        return res;
    }
}
