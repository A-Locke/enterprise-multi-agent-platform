@description('Azure region for the Content Safety resource.')
param location string

@description('Tags applied to the resource.')
param tags object

@description('Deterministic suffix for resource naming.')
param resourceToken string

// kind: 'ContentSafety' -- a distinct Cognitive Services kind from 'OpenAI' (see ai.bicep),
// evaluated per ADR-0014: a dedicated moderation layer in front of the LLM call, not a
// replacement for the model's own default content filter (raiPolicyName: Microsoft.Default
// in ai.bicep), which stays on regardless.
// Container App RBAC is wired as a separate module (ai-rbac.bicep, reused) rather than
// inline here, for the same circular-dependency reason documented in main.bicep next to
// containerAppOpenAiRbac.
resource contentSafety 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: 'cs-${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: 'F0'
  }
  kind: 'ContentSafety'
  properties: {
    customSubDomainName: 'cs-${resourceToken}'
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: true
  }
}

output endpoint string = contentSafety.properties.endpoint
output name string = contentSafety.name
output cognitiveServicesUserRoleId string = 'a97b65f3-24c7-4388-baec-2e87135dc908'
