targetScope = 'resourceGroup'

// ------------------
//    PARAMETERS
// ------------------

@description('The location where the resources will be created.')
param location string = resourceGroup().location

@description('Optional. The prefix to be used for all resources created by this template.')
param prefix string = ''

@description('Optional. The suffix to be used for all resources created by this template.')
param suffix string = ''

@description('Optional. The tags to be assigned to the created resources.')
param tags object = {}

// Container App Environment
@description('The ID of the Container Apps environment to be used for the deployment. (e.g. /subscriptions/XXX/resourceGroups/XXX/providers/Microsoft.App/managedEnvironments/XXX)')
param containerAppsEnvironmentId string

// Private Link Service
@description('Optional. The name of the private link service to be created. If set, it overrides the name generated by the template.')
param privateLinkServiceName string = '${prefix}pls-${uniqueString(resourceGroup().id)}${suffix}'

@description('The resource ID of the subnet to be used for the private link service. (e.g. /subscriptions/XXX/resourceGroups/XXX/providers/Microsoft.Network/virtualNetworks/XXX/subnets/XXX)')
param privateLinkSubnetId string

// Front Door
@description('Optional. The name of the front door profile to be created. If set, it overrides the name generated by the template.')
param frontDoorProfileName string = '${prefix}afd-${uniqueString(resourceGroup().id)}${suffix}'

@description('The name of the front door endpoint to be created.')
param frontDoorEndpointName string = 'fde-containerapps'

@description('The name of the front door origin group to be created.')
param frontDoorOriginGroupName string = 'containerapps-origin-group'

@description('The name of the front door origin to be created.')
param frontDoorOriginName string = 'containerapps-origin'

@description('The name of the front door origin route to be created.')
param frontDoorOriginRouteName string = 'containerapps-route'

@description('The host name of the front door origin to be created.')
param frontDoorOriginHostName string

// ------------------
// VARIABLES
// ------------------

var containerAppsEnvironmentTokens = split(containerAppsEnvironmentId, '/')
var containerAppsEnvironmentSubscriptionId = containerAppsEnvironmentTokens[2]
var containerAppsEnvironmentResourceGroupName = containerAppsEnvironmentTokens[4]
var containerAppsEnvironmentName = containerAppsEnvironmentTokens[8]

// ------------------
// RESOURCES
// ------------------

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2022-10-01' existing = {
  scope: resourceGroup(containerAppsEnvironmentSubscriptionId, containerAppsEnvironmentResourceGroupName)
  name: containerAppsEnvironmentName
}

module privateLinkService './modules/private-link-service.bicep' = {
  name: 'privateLinkServiceFrontDoorDeployment-${uniqueString(resourceGroup().id)}'
  params: {
    location: location
    tags: tags
    containerAppsDefaultDomainName: containerAppsEnvironment.properties.defaultDomain
    containerAppsEnvironmentSubscriptionId: containerAppsEnvironmentSubscriptionId
    privateLinkServiceName: privateLinkServiceName
    privateLinkSubnetId: privateLinkSubnetId
  }
}

module frontDoor './modules/front-door.bicep' = {
  name: 'frontDoorDeployment-${uniqueString(resourceGroup().id)}'
  params: {
    location: location
    tags: tags
    frontDoorEndpointName: frontDoorEndpointName
    frontDoorOriginGroupName: frontDoorOriginGroupName
    frontDoorOriginHostName: frontDoorOriginHostName
    frontDoorOriginName: frontDoorOriginName
    frontDoorOriginRouteName: frontDoorOriginRouteName
    frontDoorProfileName: frontDoorProfileName
    privateLinkServiceId: privateLinkService.outputs.privateLinkServiceId
  }
}

resource existingPrivateLinkService 'Microsoft.Network/privateLinkServices@2022-01-01' existing = {
  name: privateLinkServiceName
}

// ------------------
// OUTPUTS
// ------------------

// => Outputs including the private link endpoint connection ID to approve
output result object = {
  fqdn: frontDoor.outputs.fqdn
  privateLinkServiceId: privateLinkService.outputs.privateLinkServiceId
  privateLinkEndpointConnectionId: length(existingPrivateLinkService.properties.privateEndpointConnections) > 0 ? filter(existingPrivateLinkService.properties.privateEndpointConnections, (connection) => connection.properties.privateLinkServiceConnectionState.description == 'frontdoor')[0].id : ''
}