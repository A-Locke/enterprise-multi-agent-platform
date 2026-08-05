@description('Azure region for the Container App.')
param location string

@description('Tags applied to the resource. Must include azd-service-name=api for azd deploy to find this resource.')
param tags object

@description('Deterministic suffix for resource naming.')
param resourceToken string

@description('Container Apps managed environment resource ID.')
param containerAppsEnvironmentId string

@description('ACR login server, for pulling the API image.')
param acrLoginServer string

@description('ACR resource ID, for the AcrPull role assignment.')
param acrResourceId string

@description('Microsoft Entra tenant ID, passed to the app as an environment variable.')
param tenantId string

@description('Entra app registration client ID protecting the API.')
param apiClientId string

@description('Azure OpenAI endpoint (AAD-authenticated, no key).')
param openAiEndpoint string

@description('Azure OpenAI chat model deployment name.')
param openAiDeploymentName string

@description('Placeholder image used on first deploy, before azd deploy pushes the real one.')
param containerImage string = 'mcr.microsoft.com/k8se/quickstart:latest'

resource containerApp 'Microsoft.App/containerApps@2025-01-01' = {
  name: 'ca-api-${resourceToken}'
  location: location
  tags: union(tags, { 'azd-service-name': 'api' })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8000
        transport: 'auto'
      }
      // Adding this back after confirming (the hard way) that AcrPull RBAC is already
      // granted and propagated: the very first provisioning attempt included this block
      // with zero AcrPull RBAC yet (chicken-and-egg -- the role assignment below needs
      // this resource to exist first) and hung with "Operation expired" even though the
      // placeholder image was public and needed no registry at all. Once the Container App
      // existed and acrPullAssignment (below) had run at least once, re-adding this became
      // safe -- confirmed by successfully deploying the real image after re-adding it.
      registries: [
        {
          server: acrLoginServer
          identity: 'system'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'api'
          image: containerImage
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            { name: 'AZURE_TENANT_ID', value: tenantId }
            { name: 'AZURE_API_APP_CLIENT_ID', value: apiClientId }
            { name: 'AZURE_OPENAI_ENDPOINT', value: openAiEndpoint }
            { name: 'AZURE_OPENAI_DEPLOYMENT_NAME', value: openAiDeploymentName }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acrResourceId, containerApp.id, acrPullRoleId)
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: containerApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2025-04-01' existing = {
  name: last(split(acrResourceId, '/'))
}

output name string = containerApp.name
output principalId string = containerApp.identity.principalId
output fqdn string = containerApp.properties.configuration.ingress.fqdn
