
// The name of the workloard that is being deployed. Up to 10 characters long. This wil be used as part of the naming convention (i.e. as defined here: https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming) 
workloadName = "lzaaca"
//The name of the environment (e.g. "dev", "test", "prod", "preprod", "staging", "uat", "dr", "qa"). Up to 8 characters long.
environment                  = "dev"
tags                         = {}
hubResourceGroupName         = ""
vnetAddressPrefixes          = ["10.0.0.0/16"]
enableBastion                = true
bastionSubnetAddressPrefixes = ["10.0.2.0/27"]
vmSize                       = "Standard_B2ms"
vmAdminUsername              = "azureuser"
vmAdminPassword              = ""
vmLinuxSshAuthorizedKeys     = ""
vmJumpboxOSType              = "Linux"
vmJumpBoxSubnetAddressPrefix = "10.0.3.0/24"
