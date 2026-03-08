public with sharing class IntegrationQueryBuilder {
    
    public static SObject queryRecord(String objectName, List<Integration_Field_Map__mdt> mappings, Id recordId) {
        if (String.isBlank(objectName) || recordId == null) return null;
        
        Set<String> fieldsToQuery = new Set<String>{'Id'};
        Map<String, Set<String>> childQueries = new Map<String, Set<String>>();
        
        for (Integration_Field_Map__mdt m : mappings) {
            if (m.Direction__c != 'Outbound' && m.Direction__c != 'Both') continue;
            
            if (m.Is_Array__c && String.isNotBlank(m.Child_Relationship_Name__c)) {
                String childRel = m.Child_Relationship_Name__c;
                if (!childQueries.containsKey(childRel)) {
                    childQueries.put(childRel, new Set<String>());
                }
                childQueries.get(childRel).add(m.Source_Field__c);
            } else if (String.isNotBlank(m.Source_Field__c)) {
                fieldsToQuery.add(m.Source_Field__c);
            }
        }
        
        List<String> queryParts = new List<String>(fieldsToQuery);
        
        for (String childRel : childQueries.keySet()) {
            List<String> childFields = new List<String>(childQueries.get(childRel));
            if (!childFields.isEmpty()) {
                queryParts.add('(SELECT ' + String.join(childFields, ', ') + ' FROM ' + childRel + ')');
            }
        }
        
        String soql = 'SELECT ' + String.join(queryParts, ', ') + ' FROM ' + objectName + ' WHERE Id = :recordId LIMIT 1';
        
        try {
            return Database.query(soql);
        } catch (System.QueryException ex) {
            throw new IntegrationException('Failed to query ' + objectName + ' with ID ' + recordId + ': ' + ex.getMessage());
        }
    }
}
