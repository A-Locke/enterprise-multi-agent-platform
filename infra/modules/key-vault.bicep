@description('Azure region for the vault.')
param location string

@description('Tags applied to the resource.')
param tags object

@description('Deterministic suffix for resource naming.')
param resourceToken string

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: 'kv-${resourceToken}'
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    // Azure now rejects enablePurgeProtection: false on new vaults outright
    // (confirmed no subscription policy is involved — az policy assignment
    // list returned empty; this is a platform-level default). Accepted:
    // means this vault name can't be purged early after deletion, only
    // recovered or left to expire after the 7-day soft-delete retention.
    enablePurgeProtection: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

output name string = keyVault.name
output uri string = keyVault.properties.vaultUri
