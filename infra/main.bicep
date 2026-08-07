targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the azd environment; used to derive resource names and as the resource token seed.')
param environmentName string

@minLength(1)
@description('Primary Azure region for all resources.')
param location string

@description('Tags applied to every resource for cost tracking and ownership.')
param tags object = {
  'azd-env-name': environmentName
  project: 'enterprise-multi-agent-platform'
}

@description('Email address of the API Management publisher (developer portal contact). Environment-driven — set via azd env / parameters file, no hardcoded default.')
param apimPublisherEmail string

@description('Display name of the API Management publisher. Environment-driven — set via azd env / parameters file, no hardcoded default.')
param apimPublisherName string

@description('Email address for cost budget threshold alerts. Environment-driven — set via azd env / parameters file, no hardcoded default.')
param budgetNotificationEmail string

@description('Microsoft Entra tenant ID (also used for local az login context).')
param tenantId string

@description('Entra app registration client ID protecting the API (from scripts/setup-entra-app.ps1).')
param apiClientId string

@description('Object ID of the local dev principal, granted Cognitive Services OpenAI User for local testing. Empty to skip.')
param localDevPrincipalId string = ''

// Short, deterministic suffix so resource names stay unique without becoming unreadable.
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var resourceGroupName = 'rg-${environmentName}'

resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module logAnalytics './modules/log-analytics.bicep' = {
  name: 'log-analytics'
  scope: rg
  params: {
    location: location
    tags: tags
    resourceToken: resourceToken
  }
}

module keyVault './modules/key-vault.bicep' = {
  name: 'key-vault'
  scope: rg
  params: {
    location: location
    tags: tags
    resourceToken: resourceToken
  }
}

module apim './modules/apim.bicep' = {
  name: 'apim'
  scope: rg
  params: {
    location: location
    tags: tags
    resourceToken: resourceToken
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
  }
}

module containerRegistry './modules/container-registry.bicep' = {
  name: 'container-registry'
  scope: rg
  params: {
    location: location
    tags: tags
    resourceToken: resourceToken
  }
}

module budget './modules/budget.bicep' = {
  name: 'budget'
  scope: rg
  params: {
    notificationEmail: budgetNotificationEmail
  }
}

module ai './modules/ai.bicep' = {
  name: 'ai'
  scope: rg
  params: {
    location: location
    tags: tags
    resourceToken: resourceToken
    localDevPrincipalId: localDevPrincipalId
  }
}

module contentSafety './modules/content-safety.bicep' = {
  name: 'content-safety'
  scope: rg
  params: {
    location: location
    tags: tags
    resourceToken: resourceToken
  }
}

module containerAppsEnv './modules/container-apps-env.bicep' = {
  name: 'container-apps-env'
  scope: rg
  params: {
    location: location
    tags: tags
    resourceToken: resourceToken
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
  }
}

module containerAppApi './modules/container-app-api.bicep' = {
  name: 'container-app-api'
  scope: rg
  params: {
    location: location
    tags: tags
    resourceToken: resourceToken
    containerAppsEnvironmentId: containerAppsEnv.outputs.id
    acrLoginServer: containerRegistry.outputs.loginServer
    acrResourceId: containerRegistry.outputs.resourceId
    tenantId: tenantId
    apiClientId: apiClientId
    openAiEndpoint: ai.outputs.endpoint
    openAiDeploymentName: ai.outputs.deploymentName
    contentSafetyEndpoint: contentSafety.outputs.endpoint
  }
}

// Container App -> Azure OpenAI RBAC, as its own module (not inside ai.bicep) to avoid a
// circular module dependency: containerApp needs ai's outputs (endpoint), and this
// assignment needs containerApp's output (principalId). Subscription-scope files can't
// declare resource-group-scoped resources directly, even via `existing` -- must be a module.
module containerAppOpenAiRbac './modules/ai-rbac.bicep' = {
  name: 'container-app-openai-rbac'
  scope: rg
  params: {
    openAiName: ai.outputs.name
    principalId: containerAppApi.outputs.principalId
    roleDefinitionId: ai.outputs.cognitiveServicesOpenAiUserRoleId
  }
}

// Container App -> Content Safety RBAC, reusing ai-rbac.bicep (its `existing` lookup is a
// plain Microsoft.CognitiveServices/accounts reference, kind-agnostic despite the param
// name) for the same circular-dependency reason as containerAppOpenAiRbac above.
module containerAppContentSafetyRbac './modules/ai-rbac.bicep' = {
  name: 'container-app-content-safety-rbac'
  scope: rg
  params: {
    openAiName: contentSafety.outputs.name
    principalId: containerAppApi.outputs.principalId
    roleDefinitionId: contentSafety.outputs.cognitiveServicesUserRoleId
  }
}

module apimApi './modules/apim-api.bicep' = {
  name: 'apim-api'
  scope: rg
  params: {
    apimName: apim.outputs.name
    containerAppFqdn: containerAppApi.outputs.fqdn
  }
}

module knowledgeStorage './modules/knowledge-storage.bicep' = {
  name: 'knowledge-storage'
  scope: rg
  params: {
    location: location
    tags: tags
    resourceToken: resourceToken
    localDevPrincipalId: localDevPrincipalId
    aiSearchPrincipalId: aiSearch.outputs.principalId
  }
}

module aiSearch './modules/ai-search.bicep' = {
  name: 'ai-search'
  scope: rg
  params: {
    location: location
    tags: tags
    resourceToken: resourceToken
  }
}

// AI Search -> Azure OpenAI RBAC (for the embedding skill during indexing). Free tier's
// managed identity works fine for this Search-service-to-Cognitive-Services direction --
// it's specifically the Search-to-Storage direction that's key-gated on this tier (ADR-0010).
module aiSearchOpenAiRbac './modules/ai-rbac.bicep' = {
  name: 'ai-search-openai-rbac'
  scope: rg
  params: {
    openAiName: ai.outputs.name
    principalId: aiSearch.outputs.principalId
    roleDefinitionId: ai.outputs.cognitiveServicesOpenAiUserRoleId
  }
}

module monitoring './modules/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    notificationEmail: budgetNotificationEmail
    containerAppResourceId: containerAppApi.outputs.resourceId
    apimResourceId: apim.outputs.resourceId
  }
}

output RESOURCE_GROUP_NAME string = rg.name
output LOG_ANALYTICS_WORKSPACE_ID string = logAnalytics.outputs.workspaceId
output KEY_VAULT_NAME string = keyVault.outputs.name
output KEY_VAULT_URI string = keyVault.outputs.uri
output APIM_NAME string = apim.outputs.name
output APIM_GATEWAY_URL string = apim.outputs.gatewayUrl
output ACR_NAME string = containerRegistry.outputs.name
output ACR_LOGIN_SERVER string = containerRegistry.outputs.loginServer
output AZURE_OPENAI_NAME string = ai.outputs.name
output AZURE_OPENAI_ENDPOINT string = ai.outputs.endpoint
output AZURE_OPENAI_DEPLOYMENT_NAME string = ai.outputs.deploymentName
output CONTAINER_APPS_ENVIRONMENT_NAME string = containerAppsEnv.outputs.name
output CONTAINER_APP_API_NAME string = containerAppApi.outputs.name
output CONTAINER_APP_API_FQDN string = containerAppApi.outputs.fqdn
output APIM_API_PATH string = apimApi.outputs.apiPath
output AZURE_OPENAI_EMBEDDING_DEPLOYMENT_NAME string = ai.outputs.embeddingDeploymentName
output KNOWLEDGE_STORAGE_NAME string = knowledgeStorage.outputs.name
output KNOWLEDGE_STORAGE_CONTAINER_NAME string = knowledgeStorage.outputs.containerName
output AI_SEARCH_NAME string = aiSearch.outputs.name
output CONTENT_SAFETY_NAME string = contentSafety.outputs.name
output CONTENT_SAFETY_ENDPOINT string = contentSafety.outputs.endpoint
