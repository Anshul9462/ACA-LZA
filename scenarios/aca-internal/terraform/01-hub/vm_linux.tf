resource "azurerm_subnet" "snet_jumpbox" {
  name                                      = "snet-jumpbox"
  resource_group_name                       = azurerm_resource_group.rg.name
  virtual_network_name                      = azurerm_virtual_network.vnet.name
  address_prefixes                          = ["10.0.3.0/24"]
  private_endpoint_network_policies_enabled = false
}

resource "azurerm_network_security_group" "nsg_vm" {
  name                = "nsg-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "subnet" {
  subnet_id                 = azurerm_subnet.snet_jumpbox.id
  network_security_group_id = azurerm_network_security_group.nsg_vm.id
}

# Linux Server VM

module "linuxs_server" {
  source = "./modules/vm_linux"

  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  vnet_subnet_id      = azurerm_subnet.snet_jumpbox.id
  server_name         = "vm-linux-jumpbox"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  tags                = var.tags
}