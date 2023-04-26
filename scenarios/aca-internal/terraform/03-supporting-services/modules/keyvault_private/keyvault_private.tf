# Variables

variable "name" {}

variable "resource_group_name" {}

variable "location" {}

variable "tenant_id" {}

variable "snet_id" {}

variable "private_zone_id" {}

variable "tags" {}

resource "azurerm_key_vault" "keyvault" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  enabled_for_disk_encryption   = true
  tenant_id                     = var.tenant_id
  soft_delete_retention_days    = 7
  purge_protection_enabled      = false
  sku_name                      = "standard"
  public_network_access_enabled = false
  enable_rbac_authorization     = true
  tags = var.tags

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
  }
}

resource "azurerm_private_endpoint" "pe_keyvault" {
  name                = "pe-keyvault"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.snet_id
  tags = var.tags

  private_service_connection {
    name                           = "${var.name}-privateserviceconnection"
    private_connection_resource_id = azurerm_key_vault.keyvault.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "kv-endpoint-zone"
    private_dns_zone_ids = [var.private_zone_id]
  }
}

output "keyvault_id" {
  value = azurerm_key_vault.keyvault.id
}