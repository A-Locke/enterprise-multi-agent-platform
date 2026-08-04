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

output RESOURCE_GROUP_NAME string = rg.name
output LOG_ANALYTICS_WORKSPACE_ID string = logAnalytics.outputs.workspaceId
output KEY_VAULT_NAME string = keyVault.outputs.name
output KEY_VAULT_URI string = keyVault.outputs.uri
output APIM_NAME string = apim.outputs.name
output APIM_GATEWAY_URL string = apim.outputs.gatewayUrl
output ACR_NAME string = containerRegistry.outputs.name
output ACR_LOGIN_SERVER string = containerRegistry.outputs.loginServer
