public with sharing class IntegrationQueueable implements Queueable, Database.AllowsCallouts {

    private String configName;
    private List<Id> recordIds;

    public IntegrationQueueable(String configName, List<Id> recordIds) {
        this.configName = configName;
        this.recordIds = recordIds;
    }

    public void execute(QueueableContext context) {
        if (String.isBlank(configName) || recordIds == null || recordIds.isEmpty()) return;
        
        // Execute the callout for the first record (or loop through them if bulkified)
        for (Id recId : recordIds) {
            core_IntegrationService.execute(configName, recId);
        }
    }
}
