@description('Azure region for the OpenAI resource.')
param location string

@description('Tags applied to the resource.')
param tags object

@description('Deterministic suffix for resource naming.')
param resourceToken string

@description('Model deployment capacity in GlobalStandard units (rate-limit tier, not a cost commitment -- billed per-token regardless of this value).')
param modelCapacity int = 10

@description('Object ID of the local dev principal to grant Cognitive Services OpenAI User (no API keys anywhere -- Entra ID RBAC only). Empty to skip.')
param localDevPrincipalId string = ''

// kind: 'OpenAI' rather than 'AIServices' (Azure AI Foundry) -- see ADR-0005.
// disableLocalAuth: true means API keys are disabled entirely; only Entra ID RBAC works.
resource openAi 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: 'oai-${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: 'S0'
  }
  kind: 'OpenAI'
  properties: {
    customSubDomainName: 'oai-${resourceToken}'
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: true
  }
}

// gpt-4.1-mini's 2025-04-14 version turned out to be in "deprecating" state and rejected
// new deployments despite still appearing in `az cognitiveservices model list` -- verified
// gpt-5-mini's exact name/version/SKU via that command before using it here (catalog
// listings can include entries no longer deployable; check lifecycleStatus, not just presence).
//
// SKU is GlobalStandard, not DataZoneStandard: this subscription's default quota for
// gpt-5-mini is 0 under DataZoneStandard (EU-only data residency) but 500 under
// GlobalStandard (no processing-region guarantee) -- confirmed via
// `az cognitiveservices usage list`. Accepted trade-off for a portfolio-scale deployment
// with no real compliance requirement; a production engagement needing EU data residency
// would request a DataZoneStandard quota increase instead (portal, not automatable --
// see manual-setup.md #6).
resource gpt5Mini 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: openAi
  name: 'gpt-5-mini'
  sku: {
    name: 'GlobalStandard'
    capacity: modelCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-5-mini'
      version: '2025-08-07'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    raiPolicyName: 'Microsoft.Default'
  }
}

var cognitiveServicesOpenAiUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'

resource localDevRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(localDevPrincipalId)) {
  name: guid(openAi.id, localDevPrincipalId, cognitiveServicesOpenAiUserRoleId)
  scope: openAi
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAiUserRoleId)
    principalId: localDevPrincipalId
    principalType: 'User'
  }
}

output name string = openAi.name
output endpoint string = openAi.properties.endpoint
output deploymentName string = gpt5Mini.name
output resourceId string = openAi.id
output cognitiveServicesOpenAiUserRoleId string = cognitiveServicesOpenAiUserRoleId
