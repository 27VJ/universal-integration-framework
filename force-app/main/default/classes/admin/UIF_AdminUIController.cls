public with sharing class UIF_AdminUIController {

    @AuraEnabled
    public static Map<String, Object> getInitialData() {
        Map<String, Object> result = new Map<String, Object>();

        // Get Configurations
        List<Map<String, Object>> configs = new List<Map<String, Object>>();
        for (Integration_Config__mdt config : [
            SELECT Id, DeveloperName, MasterLabel, Source_Object__c, External_System__c, 
                   Direction__c, Is_Active__c, Auth_Config__c, Endpoint__c
            FROM Integration_Config__mdt
            ORDER BY DeveloperName ASC
        ]) {
            configs.add(new Map<String, Object>{
                'id' => config.Id,
                'developerName' => config.DeveloperName,
                'label' => config.MasterLabel,
                'sourceObject' => config.Source_Object__c,
                'externalSystem' => config.External_System__c,
                'direction' => config.Direction__c,
                'isActive' => config.Is_Active__c,
                'authConfig' => config.Auth_Config__c,
                'endpoint' => config.Endpoint__c,
                'status' => config.Is_Active__c ? 'Active' : 'Inactive'
            });
        }
        result.put('configurations', configs);

        // Get SF Objects
        List<Map<String, String>> sfObjects = new List<Map<String, String>>();
        for (Schema.SObjectType sObjType : Schema.getGlobalDescribe().values()) {
            Schema.DescribeSObjectResult describe = sObjType.getDescribe();
            if (describe.isQueryable() && describe.isCreateable()) {
                sfObjects.add(new Map<String, String>{
                    'label' => describe.getLabel() + ' (' + describe.getName() + ')',
                    'value' => describe.getName()
                });
            }
        }
        sfObjects.sort(new ListSorter());
        result.put('sfObjectOptions', sfObjects);

        // Get Auth Configs
        List<Map<String, String>> authConfigs = new List<Map<String, String>>();
        for (Integration_Auth__mdt auth : [SELECT DeveloperName, MasterLabel FROM Integration_Auth__mdt ORDER BY MasterLabel ASC]) {
            authConfigs.add(new Map<String, String>{
                'label' => auth.MasterLabel,
                'value' => auth.DeveloperName
            });
        }
        result.put('authOptions', authConfigs);

        return result;
    }

    @AuraEnabled
    public static Map<String, Object> getConfigDetailData(String configName, String sfObjectName) {
        Map<String, Object> result = new Map<String, Object>();

        // Get existing Mappings
        List<Map<String, Object>> mappings = new List<Map<String, Object>>();
        for (Integration_Field_Map__mdt m : [
            SELECT Id, DeveloperName, MasterLabel, Source_Field__c, Target_Field__c, 
                   Data_Type__c, Direction__c, Is_Array__c, Child_Relationship_Name__c, 
                   Array_Object_Type__c, Transform_Rule__c, Default_Value__c
            FROM Integration_Field_Map__mdt
            WHERE Integration_Config__c = :configName
            ORDER BY MasterLabel ASC
        ]) {
            mappings.add(new Map<String, Object>{
                'id' => m.Id,
                'developerName' => m.DeveloperName,
                'name' => m.MasterLabel,
                'sourceField' => m.Source_Field__c,
                'targetField' => m.Target_Field__c,
                'dataType' => m.Data_Type__c,
                'direction' => m.Direction__c,
                'isArray' => m.Is_Array__c,
                'childRelName' => m.Child_Relationship_Name__c,
                'arrayObjType' => m.Array_Object_Type__c,
                'transformRule' => m.Transform_Rule__c,
                'defaultValue' => m.Default_Value__c,
                'mappingType' => m.Is_Array__c ? 'array' : 'scalar'
            });
        }
        result.put('mappings', mappings);

        // Get SF Fields
        List<Map<String, Object>> sfFields = new List<Map<String, Object>>();
        if (String.isBlank(sfObjectName) && String.isNotBlank(configName)) {
            List<Integration_Config__mdt> confs = [SELECT Source_Object__c FROM Integration_Config__mdt WHERE DeveloperName = :configName LIMIT 1];
            if (confs.size() > 0) {
                sfObjectName = confs[0].Source_Object__c;
            }
        }

        if (String.isNotBlank(sfObjectName)) {
            Schema.SObjectType targetType = Schema.getGlobalDescribe().get(sfObjectName);
            if (targetType != null) {
                Map<String, Schema.SObjectField> fieldMap = targetType.getDescribe().fields.getMap();
                for (Schema.SObjectField field : fieldMap.values()) {
                    Schema.DescribeFieldResult fDescribe = field.getDescribe();
                    sfFields.add(new Map<String, Object>{
                        'label' => fDescribe.getLabel() + ' (' + fDescribe.getName() + ')',
                        'value' => fDescribe.getName(),
                        'type' => String.valueOf(fDescribe.getType()),
                        'isReference' => fDescribe.getType() == Schema.DisplayType.REFERENCE
                    });
                }
            }
        }
        sfFields.sort(new ListSorter());
        result.put('sfFieldOptions', sfFields);

        // Get Transform Rules
        List<Map<String, String>> transforms = new List<Map<String, String>>();
        for (Integration_Transform__mdt trans : [SELECT DeveloperName, MasterLabel FROM Integration_Transform__mdt ORDER BY MasterLabel ASC]) {
            transforms.add(new Map<String, String>{
                'label' => trans.MasterLabel,
                'value' => trans.DeveloperName
            });
        }
        result.put('transformOptions', transforms);

        return result;
    }

    @AuraEnabled
    public static List<Map<String, String>> getLookupTargetFields(String objectName, String fieldName) {
        List<Map<String, String>> result = new List<Map<String, String>>();
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(objectName);
        if (targetType != null) {
            Schema.SObjectField field = targetType.getDescribe().fields.getMap().get(fieldName);
            if (field != null) {
                Schema.DescribeFieldResult fDescribe = field.getDescribe();
                if (fDescribe.getType() == Schema.DisplayType.REFERENCE) {
                    List<Schema.SObjectType> refs = fDescribe.getReferenceTo();
                    if (refs.size() > 0) {
                        Schema.SObjectType refType = refs[0];
                        String relName = fDescribe.getRelationshipName();
                        Map<String, Schema.SObjectField> refFieldMap = refType.getDescribe().fields.getMap();
                        for (Schema.SObjectField refField : refFieldMap.values()) {
                            Schema.DescribeFieldResult refFDescribe = refField.getDescribe();
                            result.add(new Map<String, String>{
                                'label' => relName + '.' + refFDescribe.getLabel(),
                                'value' => relName + '.' + refFDescribe.getName()
                            });
                        }
                    }
                }
            }
        }
        result.sort(new ListSorter());
        return result;
    }

    @AuraEnabled
    public static String saveConfigDeploy(Map<String, Object> configData) {
        String devName = (String) configData.get('developerName');
        Boolean isNew = String.isBlank((String) configData.get('id'));

        Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
        customMetadata.fullName = 'Integration_Config__mdt.' + devName;
        customMetadata.label = (String) configData.get('developerName');

        addCustomField(customMetadata, 'Source_Object__c', (String) configData.get('sourceObject'));
        addCustomField(customMetadata, 'External_System__c', (String) configData.get('externalSystem'));
        addCustomField(customMetadata, 'Direction__c', (String) configData.get('direction'));
        addCustomField(customMetadata, 'Is_Active__c', (Boolean) configData.get('isActive'));
        
        // Ensure required fields are always populated, even with safe defaults if empty in the UI
        String authConfig = (String) configData.get('authConfig');
        addCustomField(customMetadata, 'Auth_Config__c', String.isNotBlank(authConfig) ? authConfig : 'None');
        
        String endpoint = (String) configData.get('endpoint');
        String endpointName = String.isNotBlank(endpoint) ? endpoint : (String) configData.get('externalSystem');
        addCustomField(customMetadata, 'Endpoint__c', endpointName);
        
        // Auto-provision remote site setting if an endpoint record exists
        if (String.isNotBlank(endpointName)) {
            try {
                List<Integration_Endpoint__mdt> eps = [SELECT Base_URL__c FROM Integration_Endpoint__mdt WHERE DeveloperName = :endpointName LIMIT 1];
                if (!eps.isEmpty() && String.isNotBlank(eps[0].Base_URL__c)) {
                    createRemoteSiteSetting(eps[0].Base_URL__c, endpointName + '_RSS', 'Auto-provisioned by UIF');
                }
            } catch (Exception e) {
                System.debug('Failed to auto-provision RSS: ' + e.getMessage());
            }
        }

        Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
        mdContainer.addMetadata(customMetadata);

        // Synchronous wrapper (simulated for LWC via enqueueDeployment callback)
        // Note: For real environment, you need an Async callback class.
        // Returning ID simulated.
        Id jobId = Metadata.Operations.enqueueDeployment(mdContainer, null);
        return jobId;
    }

    @AuraEnabled
    public static String saveMappingDeploy(Map<String, Object> mappingData) {
        String configDevName = (String) mappingData.get('configDevName');
        String mappingDevName = (String) mappingData.get('developerName');
        Boolean isNew = String.isBlank((String) mappingData.get('id'));

        Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
        
        // Ensure the mappingDevName doesn't already accidentally contain the config prefix from a previous save
        if (mappingDevName.startsWith(configDevName + '_')) {
            mappingDevName = mappingDevName.substring(configDevName.length() + 1);
        }
        
        String fullDevName = configDevName + '_' + mappingDevName;
        // Enforce Salesforce 40 character limit on DeveloperName
        if (fullDevName.length() > 40) {
            fullDevName = fullDevName.substring(0, 40);
            // Ensure we don't end on an underscore
            if (fullDevName.endsWith('_')) {
                fullDevName = fullDevName.substring(0, 39);
            }
        }
        
        customMetadata.fullName = 'Integration_Field_Map__mdt.' + fullDevName;
        
        String label = (String) mappingData.get('label');
        customMetadata.label = String.isNotBlank(label) ? label : mappingDevName;

        addCustomField(customMetadata, 'Integration_Config__c', configDevName);
        addCustomField(customMetadata, 'Source_Field__c', (String) mappingData.get('sourceField'));
        addCustomField(customMetadata, 'Target_Field__c', (String) mappingData.get('targetField'));
        addCustomField(customMetadata, 'Data_Type__c', (String) mappingData.get('dataType'));
        addCustomField(customMetadata, 'Is_Array__c', (Boolean) mappingData.get('isArray'));
        
        if (mappingData.get('childRelName') != null) {
            addCustomField(customMetadata, 'Child_Relationship_Name__c', (String) mappingData.get('childRelName'));
        }
        if (mappingData.get('arrayObjType') != null) {
            addCustomField(customMetadata, 'Array_Object_Type__c', (String) mappingData.get('arrayObjType'));
        }
        if (mappingData.get('transformRule') != null) {
            addCustomField(customMetadata, 'Transform_Rule__c', (String) mappingData.get('transformRule'));
        }

        Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
        mdContainer.addMetadata(customMetadata);

        Id jobId = Metadata.Operations.enqueueDeployment(mdContainer, null);
        return jobId;
    }

    @AuraEnabled
    public static String createRemoteSiteSetting(String url, String developerName, String description) {
        try {
            // Need to extract just the base URL (e.g., https://reqres.in)
            System.Url u = new System.Url(url);
            String baseUrl = u.getProtocol() + '://' + u.getHost();

            String body = '{' +
                '"FullName": "' + developerName + '",' +
                '"Metadata": {' +
                    '"disableProtocolSecurity": false,' +
                    '"isActive": true,' +
                    '"url": "' + baseUrl + '",' +
                    '"description": "' + (String.isNotBlank(description) ? description : 'Auto-provisioned by UIF') + '"' +
                '}' +
            '}';

            HttpRequest req = new HttpRequest();
            req.setEndpoint(System.Url.getOrgDomainUrl().toExternalForm() + '/services/data/v60.0/tooling/sobjects/RemoteProxy/');
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
            req.setHeader('Content-Type', 'application/json');
            req.setBody(body);

            HttpResponse res = new Http().send(req);
            
            if (res.getStatusCode() == 201) {
                return 'Success';
            } else if (res.getStatusCode() == 400 && res.getBody().contains('ALREADY_IN_PROCESS')) {
                return 'Success'; // Already exists
            } else if (res.getStatusCode() == 400 && res.getBody().contains('DUPLICATE_DEVELOPER_NAME')) {
                return 'Success'; // Already exists
            } else {
                return 'Error: ' + res.getStatusCode() + ' ' + res.getBody();
            }
        } catch (Exception e) {
            return 'Exception: ' + e.getMessage();
        }
    }

    private static void addCustomField(Metadata.CustomMetadata customMetadata, String fieldName, Object value) {
        Metadata.CustomMetadataValue customField = new Metadata.CustomMetadataValue();
        customField.field = fieldName;
        customField.value = value;
        customMetadata.values.add(customField);
    }

    // Helper for sorting maps by label
    private class ListSorter implements System.Comparator<Object> {
        public Integer compare(Object o1, Object o2) {
            Map<String, Object> m1 = (Map<String, Object>)o1;
            Map<String, Object> m2 = (Map<String, Object>)o2;
            String v1 = (String)m1.get('label');
            String v2 = (String)m2.get('label');
            if (v1 == null) return -1;
            if (v2 == null) return 1;
            return v1.compareTo(v2);
        }
    }
}
