# Universal Integration Framework

A powerful, entirely metadata-driven integration framework for Salesforce built to handle RESTful inbound and outbound integrations without writing custom point-to-point Apex code. 

## 🚀 Features

* **Zero-Code Configuration**: Connect and map Salesforce SObjects to external JSON REST APIs through an intuitive custom LWC interface directly inside Salesforce Setup.
* **Auto-Provisioned Settings**: The framework automatically generates and deploys Remote Site Settings for your endpoints upon saving.
* **Intelligent Payload Engine**: Build complex, nested JSON payloads intuitively including array support (`child.records[].field`). Extracts JSON arrays back into native SObjects seamlessly.
* **Robust Authentication Handlers**: Provides out-of-the-box support for:
  * Named Credentials
  * OAuth 2.0 (with Token Caching)
  * API Keys
  * Basic Authentication
* **Enterprise Logging & Retry Management**: Logs all payloads, status codes, and execution times to `Integration_Log__c`. Features exponential backoff queues in `Integration_Queue__c` for graceful failure handling.
* **SOQL-Free Configuration Limits**: By relying wholly on Custom Metadata Types (`Integration_Config__mdt`, `Integration_Field_Map__mdt`, etc.), mapping queries execute without touching your 100/transaction SOQL limit.

---

## 🏗️ Architecture

The framework is segmented into modular layers:

1. **Admin UI Layer (`lwc/`)**
   - `integrationConfigurator`: Main entry point for admins. Manages creation of Configs, Endpoints, and Auth policies.
   - `fieldMapper`: An advanced cascading selection tool allowing point-and-click definition of SObject and external JSON paths.
2. **Configuration Engine (`classes/core/`)**
   - Resolves data cleanly from Salesforce's Custom Metadata objects.
   - Dynamic `IntegrationQueryBuilder` parses mappings and fetches deep relationship (parent/child) queries accurately.
3. **Execution Engine (`classes/engine/`)**
   - `core_IntegrationService`: The orchestrator handling the integration lifecycle.
   - `RequestBuilder`: Compiles endpoints, injects merge fields, builds headers.
   - `PayloadTransformer`: Serializes Map/Array logic into raw JSON.
   - `ResponseParser`: Deserializes JSON responses back into target SObjects.
4. **Resiliency/Auth Layers (`classes/auth/`, `classes/error/`)**
   - Abstracted API managers, generic retry schedulers with Queueables, Error categorization strategies.

---

## 🛠️ Usage Example

You have mapped `Account` fields to sync as a `Customer` over to QuickBooks (QBO) via the Configurator UI. 

To execute it in an Apex Trigger, Flow (using an Invocable method wrapper), or Batch:

```apex
Id accountId = '001xx000003D...';

// The engine magically loads the Named Credential, shapes the JSON correctly, 
// fires the POST callout, extracts the response, and logs it.
IntegrationResult result = core_IntegrationService.execute('Sync_Account_to_QBO_Customer', accountId);

if(result.isSuccess) {
    System.debug('Integration Successful! External ID assigned: ' + result.responseBody);
} else {
    System.debug('Integration Failed: ' + result.errorMessage);
}
```

## ⚙️ Installation

To deploy the Universal Integration Framework into a Salesforce Org, push the source code via the Salesforce CLI.

```bash
# Authorize your Org
sf org login web -a MyTargetOrg

# Deploy the entire metadata project
sf project deploy start --target-org MyTargetOrg --source-dir force-app
```

Then, assign the **Universal Integration Admin** Permission Set to your System Administrator to begin granting access to the objects and framework components.

## 🔒 Security Notice

For demonstration and bootstrap purposes, the `IntegrationSecrets` apex class is configured to pass raw strings. **Before compiling this suite into a production environment, you must adapt `IntegrationSecrets.cls` to query Protected Custom Settings or use the Salesforce Security and Identity frameworks for handling raw Client Secrets natively.** Only Named Credentials should be utilized for outbound tokens.
