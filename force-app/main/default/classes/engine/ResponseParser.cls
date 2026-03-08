public with sharing class ResponseParser {

    public IntegrationResult parse(HttpResponse resp, List<Integration_Field_Map__mdt> mappings, Integration_Config__mdt config, Long elapsedMs) {
        IntegrationResult result = new IntegrationResult();
        result.statusCode = resp.getStatusCode();
        result.responseBody = resp.getBody();
        result.executionTimeMs = elapsedMs;

        if (resp.getStatusCode() >= 200 && resp.getStatusCode() < 300) {
            result.isSuccess = true;
            if (String.isNotBlank(resp.getBody())) {
                try {
                    result.parsedResponse = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
    
                    // Check for array mappings
                    List<SObject> arrayRecords = mapArrayToSObjects(result.parsedResponse, mappings);
                    if (!arrayRecords.isEmpty()) {
                        result.parsedRecords = arrayRecords;
                    }
                } catch (Exception e) {
                    result.isSuccess = false;
                    result.errorMessage = 'Failed to parse JSON response: ' + e.getMessage();
                }
            }
        } else {
            result.isSuccess = false;
            result.errorMessage = 'HTTP ' + resp.getStatusCode() + ': ' + resp.getBody();
        }
        return result;
    }

    public SObject mapToSObject(Map<String, Object> parsed, List<Integration_Field_Map__mdt> mappings, String objectType) {
        if (String.isBlank(objectType) || parsed == null || mappings == null) return null;
        
        SObject record = Schema.getGlobalDescribe().get(objectType).newSObject();
        for (Integration_Field_Map__mdt mapping : mappings) {
            if (mapping.Is_Array__c) continue; // skip arrays
            if (mapping.Direction__c == 'Inbound' || mapping.Direction__c == 'Both') {
                Object value = getNestedValue(parsed, mapping.Target_Field__c);
                if (value != null) {
                    // Try to cast the value safely
                    try {
                        record.put(mapping.Source_Field__c, value);
                    } catch(Exception e) {
                        System.debug('Type mismatch for field ' + mapping.Source_Field__c);
                    }
                }
            }
        }
        return record;
    }

    public List<SObject> mapArrayToSObjects(Map<String, Object> parsed, List<Integration_Field_Map__mdt> mappings) {
        List<SObject> results = new List<SObject>();
        
        // Group array mappings
        Map<String, List<Integration_Field_Map__mdt>> groups = new Map<String, List<Integration_Field_Map__mdt>>();
        Map<String, String> objectTypes = new Map<String, String>();
        
        for (Integration_Field_Map__mdt m : mappings) {
            if (m.Is_Array__c && (m.Direction__c == 'Inbound' || m.Direction__c == 'Both')) {
                String arrayPath = m.Child_Relationship_Name__c; // For inbound, this holds the JSON array path
                if (String.isNotBlank(arrayPath)) {
                    if (!groups.containsKey(arrayPath)) {
                        groups.put(arrayPath, new List<Integration_Field_Map__mdt>());
                    }
                    groups.get(arrayPath).add(m);
                    if (String.isNotBlank(m.Array_Object_Type__c)) {
                        objectTypes.put(arrayPath, m.Array_Object_Type__c);
                    }
                }
            }
        }
        
        // Process each group
        for (String arrayPath : groups.keySet()) {
            List<Object> rawArray = extractArray(parsed, arrayPath);
            String objType = objectTypes.get(arrayPath);
            
            if (rawArray != null && String.isNotBlank(objType)) {
                for (Object item : rawArray) {
                    if (item instanceof Map<String, Object>) {
                        SObject rec = mapToSObject((Map<String, Object>)item, groups.get(arrayPath), objType);
                        if (rec != null) results.add(rec);
                    }
                }
            }
        }
        return results;
    }

    private Object getNestedValue(Map<String, Object> parsed, String path) {
        if (parsed == null || String.isBlank(path)) return null;
        List<String> parts = path.split('\\.');
        Object current = parsed;
        
        for (Integer i = 0; i < parts.size(); i++) {
            if (current instanceof Map<String, Object>) {
                current = ((Map<String, Object>)current).get(parts[i]);
                if (current == null) return null;
            } else {
                return null;
            }
        }
        return current;
    }
    
    private List<Object> extractArray(Map<String, Object> data, String arrayPath) {
        Object val = getNestedValue(data, arrayPath);
        if (val instanceof List<Object>) {
            return (List<Object>)val;
        }
        return null;
    }
}
