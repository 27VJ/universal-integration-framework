/**
 * InboundProcessor — processes inbound webhook payloads into Salesforce records.
 * Supports both single-object and array payloads.
 */
public with sharing class InboundProcessor {

    public InboundResult process(String configName, Map<String, Object> payload) {
        Integration_Config__mdt config = IntegrationConfigProvider.getConfig(configName);
        List<Integration_Field_Map__mdt> mappings =
            IntegrationConfigProvider.getFieldMaps(configName, 'Inbound');

        ResponseParser parser = new ResponseParser();
        InboundResult result = new InboundResult();

        try {
            // Process array mappings
            List<SObject> arrayRecords = parser.mapArrayToSObjects(payload, mappings);
            if (!arrayRecords.isEmpty()) {
                List<Database.UpsertResult> uResults = Database.upsert(arrayRecords, false);
                result.isSuccess = true;
                result.recordCount = arrayRecords.size();
                result.errors = new List<String>();
                for (Database.UpsertResult ur : uResults) {
                    if (!ur.isSuccess()) {
                        result.isSuccess = false;
                        for (Database.Error err : ur.getErrors()) {
                            result.errors.add(err.getMessage());
                        }
                    }
                }
            }

            // Process single-object mapping
            SObject record = parser.mapToSObject(payload, mappings, config.Source_Object__c);
            Database.UpsertResult uResult = Database.upsert(record, false);
            if (!uResult.isSuccess()) {
                result.isSuccess = false;
                if (result.errors == null) result.errors = new List<String>();
                for (Database.Error err : uResult.getErrors()) {
                    result.errors.add(err.getMessage());
                }
            } else if (result.isSuccess == null) {
                result.isSuccess = true;
            }
            result.recordId = record.Id;

        } catch (Exception ex) {
            result.isSuccess = false;
            result.errors = new List<String>{ ex.getMessage() };
        }

        IntegrationLogger.logInbound(configName, JSON.serialize(payload), JSON.serialize(result));
        return result;
    }
}
