@description('Azure region for the workspace.')
param location string

@description('Tags applied to the resource.')
param tags object

@description('Deterministic suffix for resource naming.')
param resourceToken string

@description('Retention in days. 30 is the minimum free-tier-friendly retention for a portfolio-scale workload.')
param retentionInDays int = 30

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: 'log-${resourceToken}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    features: {
      disableLocalAuth: false
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${resourceToken}'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    IngestionMode: 'LogAnalytics'
  }
}

output workspaceId string = logAnalytics.id
output workspaceName string = logAnalytics.name
output appInsightsName string = appInsights.name
output appInsightsConnectionString string = appInsights.properties.ConnectionString
