@description('Azure region for the Container Apps environment.')
param location string

@description('Tags applied to the resource.')
param tags object

@description('Deterministic suffix for resource naming.')
param resourceToken string

@description('Log Analytics workspace resource ID, for the environment\'s log destination.')
param logAnalyticsWorkspaceId string

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
  name: last(split(logAnalyticsWorkspaceId, '/'))
}

resource containerAppsEnv 'Microsoft.App/managedEnvironments@2025-01-01' = {
  name: 'cae-${resourceToken}'
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

output id string = containerAppsEnv.id
output name string = containerAppsEnv.name
output defaultDomain string = containerAppsEnv.properties.defaultDomain
