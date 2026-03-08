/**
 * IntegrationLogPurgeBatch — scheduled batch to purge old log records.
 */
public class IntegrationLogPurgeBatch implements Database.Batchable<SObject> {

    private Integer retentionDays;

    public IntegrationLogPurgeBatch(Integer retentionDays) {
        this.retentionDays = retentionDays;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        DateTime cutoff = DateTime.now().addDays(-retentionDays);
        return Database.getQueryLocator([
            SELECT Id FROM Integration_Log__c WHERE Timestamp__c < :cutoff
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        delete scope;
    }

    public void finish(Database.BatchableContext bc) {
        // Optional: send notification
    }
}
