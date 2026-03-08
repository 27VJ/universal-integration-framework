/**
 * PayloadTransformer — builds JSON payloads from field mappings.
 * Supports both scalar fields and array fields via child relationships.
 */
public with sharing class PayloadTransformer {

    public String buildPayload(
            List<Integration_Field_Map__mdt> mappings, SObject record) {

        // Separate scalar vs. array mappings
        List<Integration_Field_Map__mdt> scalarMappings = new List<Integration_Field_Map__mdt>();
        Map<String, List<Integration_Field_Map__mdt>> arrayGroups =
            new Map<String, List<Integration_Field_Map__mdt>>();

        for (Integration_Field_Map__mdt m : mappings) {
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

        // Build scalar portion
        Map<String, Object> flatPayload = new Map<String, Object>();
        scalarMappings.sort();

        for (Integration_Field_Map__mdt mapping : scalarMappings) {
            Object value = record.get(mapping.Source_Field__c);
            if (value == null && String.isNotBlank(mapping.Default_Value__c)) {
                value = mapping.Default_Value__c;
            }
            if (String.isNotBlank(mapping.Transform_Rule__c)) {
                Integration_Transform__mdt rule =
                    IntegrationConfigProvider.getTransform(mapping.Transform_Rule__c);
                value = applyTransform(rule, value);
            }
            value = castValue(value, mapping.Data_Type__c);
            flatPayload.put(mapping.Target_Field__c, value);
        }

        Map<String, Object> payload = buildNestedJson(flatPayload);

        // Build array portions from child relationships
        for (String relName : arrayGroups.keySet()) {
            List<Integration_Field_Map__mdt> arrMappings = arrayGroups.get(relName);
            List<Map<String, Object>> childArray =
                buildChildArray(record, relName, arrMappings);
            String arrayKey = deriveArrayKey(arrMappings[0].Target_Field__c);
            payload.put(arrayKey, childArray);
        }

        return JSON.serialize(payload);
    }

    private List<Map<String, Object>> buildChildArray(
            SObject parent, String childRelName,
            List<Integration_Field_Map__mdt> arrMappings) {

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        List<SObject> children = parent.getSObjects(childRelName);
        if (children == null) return result;

        for (SObject child : children) {
            Map<String, Object> item = new Map<String, Object>();
            for (Integration_Field_Map__mdt m : arrMappings) {
                Object value = child.get(m.Source_Field__c);
                if (value == null && String.isNotBlank(m.Default_Value__c)) {
                    value = m.Default_Value__c;
                }
                if (String.isNotBlank(m.Transform_Rule__c)) {
                    Integration_Transform__mdt rule =
                        IntegrationConfigProvider.getTransform(m.Transform_Rule__c);
                    value = applyTransform(rule, value);
                }
                value = castValue(value, m.Data_Type__c);
                String fieldKey = deriveElementKey(m.Target_Field__c);
                item.put(fieldKey, value);
            }
            result.add(item);
        }
        return result;
    }

    private String deriveArrayKey(String targetField) {
        Integer idx = targetField.indexOf('[*]');
        return idx > 0 ? targetField.substring(0, idx) : targetField;
    }

    private String deriveElementKey(String targetField) {
        Integer idx = targetField.indexOf('[*].');
        return idx >= 0 ? targetField.substring(idx + 4) : targetField;
    }

    public Object applyTransform(Integration_Transform__mdt rule, Object value) {
        switch on rule.Transform_Type__c {
            when 'DateFormat'       { return TransformHandlers.formatDate(value, rule.Parameters__c); }
            when 'CurrencyConvert'  { return TransformHandlers.convertCurrency(value, rule.Parameters__c); }
            when 'ValueMap'         { return TransformHandlers.mapValue(value, rule.Parameters__c); }
            when 'Concatenate'      { return TransformHandlers.concatenate(value, rule.Parameters__c); }
            when 'Formula'          { return TransformHandlers.evaluateFormula(value, rule.Parameters__c); }
            when 'Custom'           { return TransformHandlers.executeCustom(value, rule.Apex_Class__c); }
            when else               { return value; }
        }
    }

    private Map<String, Object> buildNestedJson(Map<String, Object> flat) {
        Map<String, Object> root = new Map<String, Object>();
        for (String key : flat.keySet()) {
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
        if (value == null) return null;
        switch on dataType {
            when 'Number'   { return Decimal.valueOf(String.valueOf(value)); }
            when 'Boolean'  { return Boolean.valueOf(String.valueOf(value)); }
            when else       { return String.valueOf(value); }
        }
    }
}
