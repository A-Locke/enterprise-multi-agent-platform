@description('Azure region for the storage account.')
param location string

@description('Tags applied to the resource.')
param tags object

@description('Deterministic suffix for resource naming.')
param resourceToken string

@description('Object ID of the local dev principal, granted Storage Blob Data Contributor to upload the knowledge corpus. Empty to skip.')
param localDevPrincipalId string = ''

@description('Principal ID of the AI Search service managed identity, granted Storage Blob Data Reader for indexing. Empty to skip.')
param aiSearchPrincipalId string = ''

// Storage account names: 3-24 chars, lowercase alphanumeric only.
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'stkn${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
}

resource knowledgeContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'knowledge-docs'
  properties: {
    publicAccess: 'None'
  }
}

var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource localDevRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(localDevPrincipalId)) {
  name: guid(storage.id, localDevPrincipalId, storageBlobDataContributorRoleId)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: localDevPrincipalId
    principalType: 'User'
  }
}

var storageBlobDataReaderRoleId = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'

// ADR-0010 assumed Free-tier AI Search couldn't use managed identity for its outbound
// Storage connection at all (per Microsoft's own docs at the time) -- the "Import data"
// wizard's actual error pointed at a missing role assignment instead, and granting this
// resolved it. Correcting course: this grant works, no storage key needed after all.
resource aiSearchRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aiSearchPrincipalId)) {
  name: guid(storage.id, aiSearchPrincipalId, storageBlobDataReaderRoleId)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataReaderRoleId)
    principalId: aiSearchPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output name string = storage.name
output containerName string = knowledgeContainer.name
output resourceId string = storage.id
