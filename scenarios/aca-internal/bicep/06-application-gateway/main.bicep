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

@description('Optional. The name of the Application Gateway. If set, it overrides the name generated by the template.')
param applicationGatewayName string = '${prefix}agw-${uniqueString(resourceGroup().id)}${suffix}'
@description('The FQDN of the Application Gateawy.Must match the TLS Certificate.')
param applicationGatewayFQDN string
@description('The subnet resource id to use for Application Gateway.')
param applicationGatewaySubnetId string
@description('The FQDN of the primary backend endpoint.')
param applicationGatewayPrimaryBackendEndFQDN string
@description('The name of the public IP address to use for Application Gateway.')
param applicationGatewayPublicIpName string = '${prefix}pip-agw-${uniqueString(resourceGroup().id)}${suffix}'
@description('The name of the user assigned identity to use for Application Gateway.')
param applicationGatewayUserAssignedIdentityName string = '${prefix}id-agw-${uniqueString(resourceGroup().id)}${suffix}'

@description('Enable or disable Application Gateway Certificate (PFX).')
param enableApplicationGatewayCertificate bool
@description('The name of the certificate key to use for Application Gateway certificate.')
param applicationGatewayCertificateKeyName string

@description('Provide a resource ID of the Web Analytics WS if you need diagnostic settngs, or nothing if you don t need any.')
param applicationGatewayLogAnalyticsId string = ''

@description('The resource ID of the Key Vault.')
param keyVaultId string

// ------------------
//    VARIABLES
// ------------------

var keyVaultIdTokens = split(keyVaultId, '/')
var keyVaultSubscriptionId = keyVaultIdTokens[2]
var keyVaultResourceGroupName = keyVaultIdTokens[4]
var keyVaultName = keyVaultIdTokens[8]

var applicationGatewayCertificatePath = 'configuration/acahello.demoapp.com.pfx'

// ------------------
// DEPLOYMENT TASKS
// ------------------

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: applicationGatewayUserAssignedIdentityName
  location: location
  tags: tags
}

// => Key Vault User Assigned Identity, Secret & Role Assignement for certificate
// As of today, App Gateway does not supports  "System Managed Identity" for Key Vault
// https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-secrets-user

// => Certificates (supports only 1 for now)

module appGatewayAddCertificates './modules/app-gateway-cert.bicep' = if (enableApplicationGatewayCertificate) {
  name: 'appGatewayAddCertificates'
  scope: resourceGroup(keyVaultSubscriptionId, keyVaultResourceGroupName)
  params: {
    keyVaultName: keyVaultName
    appGatewayCertificateData: loadFileAsBase64(applicationGatewayCertificatePath)
    appGatewayCertificateKeyName: applicationGatewayCertificateKeyName
    appGatewayUserAssignedIdentityPrincipalId: userAssignedIdentity.properties.principalId
  }
}

module appGatewayConfiguration './modules/app-gateway-config.bicep'= {
  name: 'appGatewayConfiguration'
  params: {
    appGatewayName: applicationGatewayName
    location: location
    tags: tags
    appGatewayFQDN: applicationGatewayFQDN
    appGatewayPrimaryBackendEndFQDN: applicationGatewayPrimaryBackendEndFQDN
    appGatewayPublicIpName: applicationGatewayPublicIpName
    appGatewaySubnetId: applicationGatewaySubnetId
    appGatewayUserAssignedIdentityId: userAssignedIdentity.id
    keyVaultSecretId: (enableApplicationGatewayCertificate) ? appGatewayAddCertificates.outputs.SecretUri : ''
    appGatewayLogAnalyticsId: applicationGatewayLogAnalyticsId
  }
}
