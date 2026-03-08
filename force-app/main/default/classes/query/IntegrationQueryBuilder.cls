/**
 * IntegrationQueryBuilder — dynamically builds SOQL queries from field mappings.
 * Includes child sub-queries for array (Is_Array__c) mappings.
 */
public with sharing class IntegrationQueryBuilder {

    public static SObject queryRecord(
            String objectName,
            List<Integration_Field_Map__mdt> mappings,
            Id recordId) {
        String query = buildQuery(objectName, mappings, true);
        query += ' WHERE Id = :recordId LIMIT 1';
        List<SObject> results = Database.query(query);
        if (results.isEmpty()) {
            throw new IntegrationException(
                'Record not found: ' + objectName + ' with Id ' + recordId);
        }
        return results[0];
    }

    public static String buildBulkQuery(
            String objectName,
            List<Integration_Field_Map__mdt> mappings) {
        return buildQuery(objectName, mappings, true);
    }

    private static String buildQuery(
            String objectName,
            List<Integration_Field_Map__mdt> mappings,
            Boolean includeChildRelationships) {

        Set<String> parentFields = new Set<String>{ 'Id' };
        // Key = child relationship name, Value = set of child fields
        Map<String, Set<String>> childFieldsByRel = new Map<String, Set<String>>();

        for (Integration_Field_Map__mdt m : mappings) {
            if (m.Is_Array__c && String.isNotBlank(m.Child_Relationship_Name__c)) {
                String relName = m.Child_Relationship_Name__c;
                if (!childFieldsByRel.containsKey(relName)) {
                    childFieldsByRel.put(relName, new Set<String>());
                }
                childFieldsByRel.get(relName).add(m.Source_Field__c);
            } else {
                parentFields.add(m.Source_Field__c);
            }
        }

        String query = 'SELECT ' + String.join(new List<String>(parentFields), ', ');

        // Append child sub-queries
        if (includeChildRelationships && !childFieldsByRel.isEmpty()) {
            for (String relName : childFieldsByRel.keySet()) {
                Set<String> childFields = childFieldsByRel.get(relName);
                query += ', (SELECT ' + String.join(new List<String>(childFields), ', ')
                       + ' FROM ' + relName + ')';
            }
        }

        query += ' FROM ' + objectName;
        return query;
    }
}
