public with sharing class IntegrationConfigProvider {

    public static Integration_Config__mdt getConfig(String configName) {
        List<Integration_Config__mdt> configs = [
            SELECT DeveloperName, MasterLabel, Source_Object__c, External_System__c, Direction__c,
                   Execution_Type__c, Batch_Size__c, Timeout__c, Max_Retries__c, Retry_Interval_Seconds__c,
                   Endpoint__c, Auth_Config__c
            FROM Integration_Config__mdt 
            WHERE DeveloperName = :configName AND Is_Active__c = true
            LIMIT 1
        ];
        if (configs.isEmpty()) {
            throw new IntegrationException('Active Integration Config not found: ' + configName);
        }
        return configs[0];
    }

    public static List<Integration_Field_Map__mdt> getFieldMaps(String configName, String direction) {
        List<Integration_Field_Map__mdt> maps = new List<Integration_Field_Map__mdt>();
        
        // Either Outbound, Inbound, or Both
        for (Integration_Field_Map__mdt m : [
            SELECT DeveloperName, Source_Field__c, Target_Field__c, Data_Type__c,
                   Default_Value__c, Transform_Rule__c, Direction__c, Sort_Order__c,
                   Is_Array__c, Child_Relationship_Name__c, Array_Object_Type__c
            FROM Integration_Field_Map__mdt
            WHERE Integration_Config__c = :configName
            ORDER BY Sort_Order__c ASC NULLS LAST
        ]) {
            if (m.Direction__c == direction || m.Direction__c == 'Both') {
                maps.add(m);
            }
        }
        return maps;
    }

    public static Integration_Endpoint__mdt getEndpoint(String endpointName) {
        if (String.isBlank(endpointName)) return null;
        List<Integration_Endpoint__mdt> endpoints = [
            SELECT DeveloperName, Base_URL__c, Path__c, HTTP_Method__c, 
                   Content_Type__c, Custom_Headers__c, Query_Parameters__c
            FROM Integration_Endpoint__mdt 
            WHERE DeveloperName = :endpointName
            LIMIT 1
        ];
        if (endpoints.isEmpty()) {
            throw new IntegrationException('Integration Endpoint not found: ' + endpointName);
        }
        return endpoints[0];
    }

    public static Integration_Auth__mdt getAuth(String authName) {
        if (String.isBlank(authName) || authName == 'None') return null;
        List<Integration_Auth__mdt> auths = [
            SELECT DeveloperName, Auth_Type__c, Named_Credential__c, Token_Endpoint__c,
                   Client_Id_Field__c, Client_Secret_Field__c, Scope__c, 
                   Auth_Header_Name__c, Token_Cache_Seconds__c
            FROM Integration_Auth__mdt 
            WHERE DeveloperName = :authName
            LIMIT 1
        ];
        if (auths.isEmpty()) {
            throw new IntegrationException('Integration Auth config not found: ' + authName);
        }
        return auths[0];
    }
    
    public static Integration_Auth__mdt getAuthByConfig(String configName) {
        Integration_Config__mdt config = getConfig(configName);
        return getAuth(config.Auth_Config__c);
    }
    
    public static Integration_Transform__mdt getTransform(String transformName) {
        if (String.isBlank(transformName)) return null;
        List<Integration_Transform__mdt> transforms = [
            SELECT DeveloperName, Transform_Type__c, Parameters__c, Apex_Class__c
            FROM Integration_Transform__mdt 
            WHERE DeveloperName = :transformName
            LIMIT 1
        ];
        return transforms.isEmpty() ? null : transforms[0];
    }
}
