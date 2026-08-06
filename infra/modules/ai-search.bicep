@description('Azure region for the AI Search service.')
param location string

@description('Tags applied to the resource.')
param tags object

@description('Deterministic suffix for resource naming.')
param resourceToken string

// Free (F0) tier -- see ADR-0010.
resource search 'Microsoft.Search/searchServices@2025-05-01' = {
  name: 'srch-${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: 'free'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'Default'
    publicNetworkAccess: 'enabled'
    // Defaults to apiKeyOnly if unset -- RBAC role assignments on this service (Search
    // Service Contributor, Search Index Data Contributor) are silently ineffective without
    // this, since the data-plane REST API rejects AAD bearer tokens entirely in that mode.
    // Found the hard way: a 403 that looked like RBAC-propagation lag was actually this.
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
  }
}

output name string = search.name
output principalId string = search.identity.principalId
output resourceId string = search.id
