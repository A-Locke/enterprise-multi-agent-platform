@description('Name of the existing APIM instance.')
param apimName string

@description('FQDN of the Container App backing this API.')
param containerAppFqdn string

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimName
}

resource backend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  parent: apim
  name: 'api-backend'
  properties: {
    url: 'https://${containerAppFqdn}'
    protocol: 'http'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}

// Passthrough API: APIM forwards everything to the Container App. Per-operation
// definitions (imported from the API's own OpenAPI spec) can replace this once policies
// need to differentiate by route -- not needed yet at Milestone 2.
resource api 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'platform-api'
  properties: {
    displayName: 'Enterprise Multi-Agent Platform API'
    path: 'api'
    protocols: ['https']
    subscriptionRequired: false
    serviceUrl: 'https://${containerAppFqdn}'
  }
}

// APIM has no true method wildcard -- `method: '*'` silently matches nothing, so every
// request 404s at the gateway (confirmed the hard way: operation existed, config looked
// right, real cause was this). One operation per method needed, per
// https://ronaldbosma.github.io/blog/2025/12/15/catch-all-api-in-azure-api-management-forward-any-request/
var httpMethodsToCatch = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']

resource wildcardOperations 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = [
  for method in httpMethodsToCatch: {
    parent: api
    name: 'passthrough-${toLower(method)}'
    properties: {
      displayName: 'Passthrough ${method}'
      method: method
      urlTemplate: '/{*path}'
      templateParameters: [
        {
          name: 'path'
          type: 'string'
          required: true
        }
      ]
    }
  }
]

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: api
  name: 'policy'
  properties: {
    format: 'xml'
    value: '<policies><inbound><base /><set-backend-service backend-id="${backend.name}" /></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
  }
}

output apiPath string = api.properties.path
