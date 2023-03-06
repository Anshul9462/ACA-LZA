targetScope = 'subscription'

// ------------------
//    PARAMETERS
// ------------------

@description('The location where the resources will be created.')
param location string = deployment().location

param workloadName string

param environmentName string

param locationShortName string

@description('Optional. The name of the resource group to create the resources in. If set, it overrides the name generated by the template.')
param spokeResourceGroupName string = 'rg-${workloadName}-${environmentName}-${locationShortName}'

@description('Optional. The tags to be assigned to the created resources.')
param tags object = {}

// Hub
@description('The resource ID of the Hub Virtual Network.')
param hubVNetId string

// Spoke
@description('Optional. The name of the virtual network to create for the spoke. If set, it overrides the name generated by the template.')
param spokeVNetName string = 'vnet-${workloadName}-${environmentName}-${locationShortName}'

@description('CIDR of the Spoke Virtual Network.')
param spokeVNetAddressPrefixes array

@description('Optional. The name of the subnet to create for the spoke infrastructure. If set, it overrides the name generated by the template.')
param spokeInfraSubnetName string = 'snet-infra'

@description('CIDR of the Spoke Infrastructure Subnet.')
param spokeInfraSubnetAddressPrefix string

@description('Optional. The name of the subnet to create for the spoke private endpoints. If set, it overrides the name generated by the template.')
param spokePrivateEndpointsSubnetName string = 'snet-pep'

@description('CIDR of the Spoke Private Endpoints Subnet.')
param spokePrivateEndpointsSubnetAddressPrefix string

@description('Optional. The name of the subnet to create for the spoke application gateway. If set, it overrides the name generated by the template.')
param spokeApplicationGatewaySubnetName string = 'snet-agw'

@description('CIDR of the Spoke Application Gateway Subnet. If the value is emnpty, the subnet will not be created.')
param spokeApplicationGatewaySubnetAddressPrefix string

// ------------------
// VARIABLES
// ------------------

var hubVNetResourIdTokens = !empty(hubVNetId) ? split(hubVNetId, '/') : array('')
var hubSubscriptionId = hubVNetResourIdTokens[2]
var hubResourceGroupName = hubVNetResourIdTokens[4]
var hubVNetName = hubVNetResourIdTokens[8]

// => Subnet definition taking in consideration feature flags
var defaultSubnets = [
  {
    name: spokeInfraSubnetName
    properties: {
      addressPrefix: spokeInfraSubnetAddressPrefix
    }
  }
  {
    name: spokePrivateEndpointsSubnetName
    properties: {
      addressPrefix: spokePrivateEndpointsSubnetAddressPrefix
    }
  }
]

// Append optional application gateway subnet, if required
var spokeSubnets = !empty(spokeApplicationGatewaySubnetAddressPrefix) ? concat(defaultSubnets, [
    {
      name: spokeApplicationGatewaySubnetName
      properties: {
        addressPrefix: spokeApplicationGatewaySubnetAddressPrefix
      }
    }
  ]) : defaultSubnets

// ------------------
// RESOURCES
// ------------------

resource spokeResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: spokeResourceGroupName
  location: location
  tags: tags
}

module spokeVNet '../modules/vnet.bicep' = {
  name: '${deployment().name}-spokeVNet'
  scope: spokeResourceGroup
  params: {
    vnetName: spokeVNetName
    location: location
    tags: tags
    subnets: spokeSubnets
    vnetAddressPrefixes: spokeVNetAddressPrefixes
  }
}

module peerSpokeToHub '../modules/peering.bicep' = if (!empty(hubVNetId))  {
  name: '${deployment().name}-peerSpokeToHubDeployment'
  scope: spokeResourceGroup
  params: {
    localVnetName: spokeVNet.outputs.vnetName
    remoteSubscriptionId: hubSubscriptionId
    remoteRgName: hubResourceGroupName
    remoteVnetName: hubVNetName
  }
}

module peerHubToSpoke '../modules/peering.bicep' = if (!empty(hubVNetId) )  {
  name: '${deployment().name}-peerHubToSpokeDeployment'
  scope: resourceGroup(hubSubscriptionId, hubResourceGroupName)
    params: {
      localVnetName: hubVNetName
      remoteSubscriptionId: last(split(subscription().id, '/'))!
      remoteRgName: spokeResourceGroup.name
      remoteVnetName: spokeVNet.outputs.vnetName
  }
}

// => Retrieve Subnets

resource createdSpokeVNet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: spokeVNet.outputs.vnetName
  scope: spokeResourceGroup
}

resource spokeInfraSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  parent: createdSpokeVNet
  name: spokeInfraSubnetName
}

resource spokePrivateEndpointsSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  parent: createdSpokeVNet
  name: spokePrivateEndpointsSubnetName
}

resource spokeApplicationGatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = if (!empty(spokeApplicationGatewaySubnetAddressPrefix)) {
  parent: createdSpokeVNet
  name: spokeApplicationGatewaySubnetName
}

// ------------------
// OUTPUTS
// ------------------

@description('The name of the Hub resource group.')
output spokeResourceGroupName string = spokeResourceGroup.name

@description('The  resource ID of the Spoke Virtual Network.')
output spokeVNetId string = createdSpokeVNet.id

@description('The name of the Spoke Virtual Network.')
output spokeVNetName string = createdSpokeVNet.name

@description('The resource ID of the Spoke Infrastructure Subnet.')
output spokeInfraSubnetId string = spokeInfraSubnet.id

@description('The name of the Spoke Infrastructure Subnet.')
output spokeInfraSubnetName string = spokeInfraSubnet.name

@description('The resource ID of the Spoke Private Endpoints Subnet.')
output spokePrivateEndpointsSubnetId string = spokePrivateEndpointsSubnet.id

@description('The name of the Spoke Private Endpoints Subnet.')
output spokePrivateEndpointsSubnetName string = spokePrivateEndpointsSubnet.name

@description('The resource ID of the Spoke Application Gateway Subnet. If "spokeApplicationGatewaySubnetAddressPrefix" is empty, the subnet will not be created and the value returned is empty.')
output spokeApplicationGatewaySubnetId string = (!empty(spokeApplicationGatewaySubnetAddressPrefix)) ? spokeApplicationGatewaySubnet.id : ''

@description('The name of the Spoke Application Gateway Subnet.  If "spokeApplicationGatewaySubnetAddressPrefix" is empty, the subnet will not be created and the value returned is empty.')
output spokeApplicationGatewaySubnetName string = (!empty(spokeApplicationGatewaySubnetAddressPrefix)) ? spokeApplicationGatewaySubnet.name : ''
