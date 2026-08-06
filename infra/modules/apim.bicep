@description('Azure region for the APIM instance.')
param location string

@description('Tags applied to the resource.')
param tags object

@description('Deterministic suffix for resource naming.')
param resourceToken string

@description('Log Analytics workspace resource ID for diagnostic settings.')
param logAnalyticsWorkspaceId string

@description('Email address of the API publisher, shown on the developer portal. Environment-driven — no default.')
param publisherEmail string

@description('Display name of the API publisher, shown on the developer portal. Environment-driven — no default.')
param publisherName string

// Consumption tier: pay-per-call, no idle base cost, no built-in VNet integration or
// SLA-backed availability. Chosen deliberately for a portfolio-scale/dev workload;
// document Standard/Premium tier trade-offs in the cost analysis when this
// deployment moves toward a production posture.
resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: 'apim-${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: 'Consumption'
    capacity: 0
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

resource apimDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'apim-diagnostics'
  scope: apim
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output name string = apim.name
output gatewayUrl string = apim.properties.gatewayUrl
output resourceId string = apim.id
