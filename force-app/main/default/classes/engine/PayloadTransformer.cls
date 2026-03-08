public with sharing class PayloadTransformer {

    public String buildPayload(List<Integration_Field_Map__mdt> mappings, SObject record) {
        if (record == null || mappings == null || mappings.isEmpty()) return '{}';

        // Separate scalar vs. array mappings
        List<Integration_Field_Map__mdt> scalarMappings = new List<Integration_Field_Map__mdt>();
        Map<String, List<Integration_Field_Map__mdt>> arrayGroups = new Map<String, List<Integration_Field_Map__mdt>>();

        for (Integration_Field_Map__mdt m : mappings) {
            if (m.Direction__c != 'Outbound' && m.Direction__c != 'Both') continue;
            
            if (m.Is_Array__c && String.isNotBlank(m.Child_Relationship_Name__c)) {
                String relName = m.Child_Relationship_Name__c;
                if (!arrayGroups.containsKey(relName)) {
                    arrayGroups.put(relName, new List<Integration_Field_Map__mdt>());
                }
                arrayGroups.get(relName).add(m);
            } else {
                scalarMappings.add(m);
            }
        }

        // Build the scalar portion
        Map<String, Object> flatPayload = new Map<String, Object>();

        for (Integration_Field_Map__mdt mapping : scalarMappings) {
            Object value = getFieldValueSafely(record, mapping.Source_Field__c);
            
            if (value == null && String.isNotBlank(mapping.Default_Value__c)) {
                value = mapping.Default_Value__c;
            }
            if (String.isNotBlank(mapping.Transform_Rule__c)) {
                Integration_Transform__mdt rule = IntegrationConfigProvider.getTransform(mapping.Transform_Rule__c);
                if (rule != null) {
                   value = applyTransform(rule, value);
                }
            }
            value = castValue(value, mapping.Data_Type__c);
            flatPayload.put(mapping.Target_Field__c, value);
        }

        Map<String, Object> payload = buildNestedJson(flatPayload);

        // Build array portions
        for (String relName : arrayGroups.keySet()) {
            List<Integration_Field_Map__mdt> arrMappings = arrayGroups.get(relName);
            List<Map<String, Object>> childArray = buildChildArray(record, relName, arrMappings);

            // Derive the JSON array key from Target_Field__c. e.g., "contacts[*].email" -> "contacts"
            String arrayKey = deriveArrayKey(arrMappings[0].Target_Field__c);
            payload.put(arrayKey, childArray);
        }

        return JSON.serialize(payload, true); // true = suppress nulls
    }

    private List<Map<String, Object>> buildChildArray(SObject parent, String childRelName, List<Integration_Field_Map__mdt> arrMappings) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        List<SObject> children = null;
        
        try {
            children = parent.getSObjects(childRelName);
        } catch (System.SObjectException ex) {
            // Relationship not fetched or doesn't exist
            return result;
        }
        
        if (children == null) return result;

        for (SObject child : children) {
            Map<String, Object> flatItem = new Map<String, Object>();
            for (Integration_Field_Map__mdt m : arrMappings) {
                Object value = getFieldValueSafely(child, m.Source_Field__c);
                if (value == null && String.isNotBlank(m.Default_Value__c)) {
                    value = m.Default_Value__c;
                }
                if (String.isNotBlank(m.Transform_Rule__c)) {
                    Integration_Transform__mdt rule = IntegrationConfigProvider.getTransform(m.Transform_Rule__c);
                    if (rule != null) value = applyTransform(rule, value);
                }
                value = castValue(value, m.Data_Type__c);

                // Strip the array prefix: "contacts[*].email" -> "email"
                String fieldKey = deriveElementKey(m.Target_Field__c);
                flatItem.put(fieldKey, value);
            }
            // If the array item has nested properties internally ("address.city"), build them
            result.add(buildNestedJson(flatItem));
        }
        return result;
    }

    private String deriveArrayKey(String targetField) {
        if (String.isBlank(targetField)) return 'arrayData';
        Integer idx = targetField.indexOf('[*]');
        return (idx > 0) ? targetField.substring(0, idx) : targetField;
    }

    private String deriveElementKey(String targetField) {
        if (String.isBlank(targetField)) return 'field';
        Integer idx = targetField.indexOf('[*].');
        return (idx >= 0) ? targetField.substring(idx + 4) : targetField;
    }
    
    // Support cross-object fields like Account.Owner.Name
    private Object getFieldValueSafely(SObject record, String fieldPath) {
        if (record == null || String.isBlank(fieldPath)) return null;
        
        if (!fieldPath.contains('.')) {
            try { return record.get(fieldPath); } catch (Exception e) { return null; }
        }
        
        List<String> parts = fieldPath.split('\\.');
        SObject currentObj = record;
        for (Integer i = 0; i < parts.size() - 1; i++) {
            try {
                currentObj = currentObj.getSObject(parts[i]);
                if (currentObj == null) return null;
            } catch (Exception e) { return null; }
        }
        try { return currentObj.get(parts[parts.size() - 1]); } catch (Exception e) { return null; }
    }

    public Object applyTransform(Integration_Transform__mdt rule, Object value) {
        if (rule == null) return value;
        // Basic placeholder for now, TransformHandlers should be implemented separately
        return value;
    }

    private Map<String, Object> buildNestedJson(Map<String, Object> flat) {
        Map<String, Object> root = new Map<String, Object>();
        for (String key : flat.keySet()) {
            if (key == null) continue;
            List<String> parts = key.split('\\.');
            Map<String, Object> current = root;
            for (Integer i = 0; i < parts.size() - 1; i++) {
                if (!current.containsKey(parts[i])) {
                    current.put(parts[i], new Map<String, Object>());
                }
                current = (Map<String, Object>) current.get(parts[i]);
            }
            current.put(parts[parts.size() - 1], flat.get(key));
        }
        return root;
    }

    private Object castValue(Object value, String dataType) {
        if (value == null || String.isBlank(dataType)) return value;
        try {
            switch on dataType {
                when 'Integer' { return Integer.valueOf(value); }
                when 'Decimal' { return Decimal.valueOf(String.valueOf(value)); }
                when 'Boolean' { return Boolean.valueOf(String.valueOf(value)); }
                when 'Date' { 
                    if (value instanceof Date) return String.valueOf((Date)value);
                    if (value instanceof DateTime) return ((DateTime)value).date().format();
                    return String.valueOf(value);
                }
                when else { return String.valueOf(value); }
            }
        } catch (Exception ex) {
            return value; // fall back to original if casting fails
        }
    }
}
