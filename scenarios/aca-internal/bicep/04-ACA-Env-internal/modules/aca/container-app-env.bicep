param name string
param location string = resourceGroup().location
param lawClientId string
param lawClientSecret string
param infrasubnet string
param applicationInsightsName string = ''
//param runtimesubnet string

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(applicationInsightsName)) {
  name: applicationInsightsName
}


resource environment 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: name
  location: location
  
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: lawClientId
        sharedKey: lawClientSecret
      }
    }
    daprAIInstrumentationKey: (!empty(applicationInsightsName) ? applicationInsights.properties.InstrumentationKey : null)
    vnetConfiguration: {
      internal: true
      infrastructureSubnetId: infrasubnet
      dockerBridgeCidr: '10.2.0.1/16'
      platformReservedCidr: '10.3.0.0/16'
      platformReservedDnsIP: '10.3.0.2'
     // runtimeSubnetId: infrasubnet
    }
    zoneRedundant: true
  } 
}

output envid string = environment.id
output envfqdn string = environment.properties.defaultDomain
output envip string = environment.properties.staticIp