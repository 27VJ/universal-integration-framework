/**
 * ResponseParser — parses HTTP responses and maps to SObjects.
 * Supports single-object and array inbound responses.
 */
public with sharing class ResponseParser {

    public IntegrationResult parse(
            HttpResponse resp,
            List<Integration_Field_Map__mdt> mappings,
            Integration_Config__mdt config,
            Long elapsedMs) {

        IntegrationResult result = new IntegrationResult();
        result.statusCode = resp.getStatusCode();
        result.responseBody = resp.getBody();
        result.executionTimeMs = elapsedMs;

        if (resp.getStatusCode() >= 200 && resp.getStatusCode() < 300) {
            result.isSuccess = true;
            if (String.isNotBlank(resp.getBody())) {
                result.parsedResponse =
                    (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());

                // Check for array mappings
                List<SObject> arrayRecords =
                    mapArrayToSObjects(result.parsedResponse, mappings);
                if (!arrayRecords.isEmpty()) {
                    result.parsedRecords = arrayRecords;
                }
            }
        } else {
            result.isSuccess = false;
            result.errorMessage = 'HTTP ' + resp.getStatusCode() + ': ' + resp.getBody();
        }
        return result;
    }

    // Single-object inbound mapping
    public SObject mapToSObject(
            Map<String, Object> parsed,
            List<Integration_Field_Map__mdt> mappings,
            String objectType) {
        SObject record = Schema.getGlobalDescribe().get(objectType).newSObject();
        for (Integration_Field_Map__mdt mapping : mappings) {
            if (mapping.Is_Array__c) continue;
            if (mapping.Direction__c == 'Inbound' || mapping.Direction__c == 'Both') {
                Object value = getNestedValue(parsed, mapping.Target_Field__c);
                if (value != null) {
                    record.put(mapping.Source_Field__c, value);
                }
            }
        }
        return record;
    }

    // Array inbound mapping — iterates JSON arrays and maps to SObject list
    public List<SObject> mapArrayToSObjects(
            Map<String, Object> parsed,
            List<Integration_Field_Map__mdt> mappings) {

        List<SObject> allRecords = new List<SObject>();

        Map<String, List<Integration_Field_Map__mdt>> arrayGroups =
            new Map<String, List<Integration_Field_Map__mdt>>();
        Map<String, String> groupObjectType = new Map<String, String>();

        for (Integration_Field_Map__mdt m : mappings) {
            if (!m.Is_Array__c) continue;
            if (m.Direction__c != 'Inbound' && m.Direction__c != 'Both') continue;

            String arrayPath = m.Child_Relationship_Name__c;
            if (!arrayGroups.containsKey(arrayPath)) {
                arrayGroups.put(arrayPath, new List<Integration_Field_Map__mdt>());
                groupObjectType.put(arrayPath, m.Array_Object_Type__c);
            }
            arrayGroups.get(arrayPath).add(m);
        }

        for (String arrayPath : arrayGroups.keySet()) {
            List<Object> elements = extractArray(parsed, arrayPath);
            if (elements == null) continue;

            String objType = groupObjectType.get(arrayPath);
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(objType);
            List<Integration_Field_Map__mdt> arrMappings = arrayGroups.get(arrayPath);

            for (Object elem : elements) {
                if (!(elem instanceof Map<String, Object>)) continue;
                Map<String, Object> elemMap = (Map<String, Object>) elem;

                SObject rec = sot.newSObject();
                for (Integration_Field_Map__mdt m : arrMappings) {
                    String elemKey = deriveElementKey(m.Target_Field__c);
                    Object value = getNestedValue(elemMap, elemKey);
                    if (value != null) {
                        rec.put(m.Source_Field__c, value);
                    }
                }
                allRecords.add(rec);
            }
        }
        return allRecords;
    }

    private List<Object> extractArray(Map<String, Object> data, String arrayPath) {
        List<String> parts = arrayPath.split('\\.');
        Object current = data;
        for (String part : parts) {
            if (current instanceof Map<String, Object>) {
                current = ((Map<String, Object>) current).get(part);
            } else {
                return null;
            }
        }
        if (current instanceof List<Object>) {
            return (List<Object>) current;
        }
        return null;
    }

    private String deriveElementKey(String targetField) {
        Integer idx = targetField.indexOf('[*].');
        return idx >= 0 ? targetField.substring(idx + 4) : targetField;
    }

    private Object getNestedValue(Map<String, Object> data, String path) {
        List<String> parts = path.split('\\.');
        Object current = data;
        for (String part : parts) {
            if (current instanceof Map<String, Object>) {
                current = ((Map<String, Object>) current).get(part);
            } else {
                return null;
            }
        }
        return current;
    }
}
