/**
 * IntegrationBatch — batch processing for large-volume integrations.
 */
public class IntegrationBatch
        implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

    private String configName;
    private Integer successCount = 0;
    private Integer failureCount = 0;

    public IntegrationBatch(String configName) {
        this.configName = configName;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Integration_Config__mdt config = IntegrationConfigProvider.getConfig(configName);
        List<Integration_Field_Map__mdt> mappings =
            IntegrationConfigProvider.getFieldMaps(configName, 'Outbound');
        String query = IntegrationQueryBuilder.buildBulkQuery(config.Source_Object__c, mappings);
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        for (SObject record : scope) {
            IntegrationResult result = IntegrationService.execute(configName, record.Id);
            if (result.isSuccess) { successCount++; } else { failureCount++; }
        }
    }

    public void finish(Database.BatchableContext bc) {
        IntegrationLogger.logBatchSummary(configName, successCount, failureCount);
    }
}
