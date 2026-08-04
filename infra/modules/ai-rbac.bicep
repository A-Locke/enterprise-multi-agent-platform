@description('Name of the existing Azure OpenAI account.')
param openAiName string

@description('Principal ID to grant Cognitive Services OpenAI User.')
param principalId string

@description('Cognitive Services OpenAI User role definition ID.')
param roleDefinitionId string

resource openAi 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: openAiName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAi.id, principalId, roleDefinitionId)
  scope: openAi
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
