@description('Email address to notify on alert firing. Reuses the same address as the cost budget guardrail.')
param notificationEmail string

@description('Resource ID of the API Container App.')
param containerAppResourceId string

@description('Resource ID of the APIM instance.')
param apimResourceId string

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-ops-alerts'
  location: 'global'
  properties: {
    groupShortName: 'ops-alerts'
    enabled: true
    emailReceivers: [
      {
        name: 'ops-notification'
        emailAddress: notificationEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

// Alerts on a *spike* in restarts (>=3 in 15 minutes), not any single restart -- Milestone 4
// documented that Container Apps can legitimately recycle a replica occasionally even with
// minReplicas: 1 (platform-level node patching, health-probe hiccups), and that's expected,
// self-healing behavior, not something worth paging on. A crash loop (repeated restarts in a
// short window) is the actual signal worth alerting on.
resource restartAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-containerapp-restart-spike'
  location: 'global'
  properties: {
    description: 'Fires if the API Container App restarts 3+ times within 15 minutes -- a crash loop, not the occasional single restart already documented as expected platform behavior.'
    severity: 2
    enabled: true
    scopes: [containerAppResourceId]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          name: 'RestartSpike'
          metricName: 'RestartCount'
          metricNamespace: 'Microsoft.App/containerApps'
          operator: 'GreaterThanOrEqual'
          threshold: 3
          timeAggregation: 'Total'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

resource apimFailedRequestsAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-apim-failed-requests'
  location: 'global'
  properties: {
    description: 'Fires if APIM reports 5+ failed requests within 15 minutes -- catches backend-down or auth-misconfiguration scenarios at the gateway.'
    severity: 2
    enabled: true
    scopes: [apimResourceId]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          name: 'FailedRequestsSpike'
          metricName: 'FailedRequests'
          metricNamespace: 'Microsoft.ApiManagement/service'
          operator: 'GreaterThanOrEqual'
          threshold: 5
          timeAggregation: 'Total'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

output actionGroupId string = actionGroup.id
