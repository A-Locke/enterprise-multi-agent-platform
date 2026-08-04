@description('Monthly budget amount in the subscription billing currency. Default is 90% of the $200 Azure free-account credit per ADR-0002.')
param amount int = 180

@description('Email address to notify on threshold breach. Environment-driven — no hardcoded default.')
param notificationEmail string

@description('Budget start date, first of the current month (UTC).')
param startDate string = utcNow('yyyy-MM-01')

@description('Budget end date — ten years out, since Consumption/budgets requires one for a recurring monthly budget.')
param endDate string = dateTimeAdd(utcNow('yyyy-MM-dd'), 'P10Y', 'yyyy-MM-dd')

var thresholds = [50, 75, 90, 100]

resource budget 'Microsoft.Consumption/budgets@2023-05-01' = {
  name: 'budget-monthly-guardrail'
  properties: {
    category: 'Cost'
    amount: amount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: startDate
      endDate: endDate
    }
    notifications: toObject(thresholds, t => 'threshold-${t}', t => {
      enabled: true
      operator: 'GreaterThanOrEqualTo'
      threshold: t
      contactEmails: [
        notificationEmail
      ]
      thresholdType: 'Actual'
    })
  }
}

output name string = budget.name
