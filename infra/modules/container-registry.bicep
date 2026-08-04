@description('Azure region for the registry.')
param location string

@description('Tags applied to the resource.')
param tags object

@minLength(13)
@description('Deterministic suffix for resource naming (uniqueString() output, always 13 chars).')
param resourceToken string

// Basic tier: ~$5/month flat, no free tier. Accepted per ADR-0002 (prefer
// Azure-native services within the 30-day free-credit window) in favor of
// GitHub Container Registry, mainly for native managed-identity pull auth
// into Container Apps instead of managing a PAT.
resource acr 'Microsoft.ContainerRegistry/registries@2025-04-01' = {
  name: 'acr${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

output name string = acr.name
output loginServer string = acr.properties.loginServer
output resourceId string = acr.id
