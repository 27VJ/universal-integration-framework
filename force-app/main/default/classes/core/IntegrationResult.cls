/**
 * IntegrationResult — return value from integration execution.
 */
public with sharing class IntegrationResult {

    public Boolean isSuccess;
    public Integer statusCode;
    public String responseBody;
    public String errorMessage;
    public Long executionTimeMs;
    public Map<String, Object> parsedResponse;
    public List<SObject> parsedRecords;

    public static IntegrationResult failure(String message) {
        IntegrationResult r = new IntegrationResult();
        r.isSuccess = false;
        r.errorMessage = message;
        return r;
    }

    public static IntegrationResult success(String body) {
        IntegrationResult r = new IntegrationResult();
        r.isSuccess = true;
        r.responseBody = body;
        return r;
    }
}
