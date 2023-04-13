module "network" {
  source = "registry.terraform.io/libre-devops/network/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  vnet_name     = "vnet-${var.short}-${var.loc}-${terraform.workspace}-01" // vnet-ldo-euw-dev-01
  vnet_location = module.network.vnet_location

  address_space = ["10.0.0.0/16"]
  subnet_prefixes = [
    "10.0.0.0/24",
  ]
  subnet_names = [
    "sn1-${module.network.vnet_name}",
  ]
  subnet_service_endpoints = {
    "sn1-${module.network.vnet_name}" = ["Microsoft.Storage", "Microsoft.Keyvault", "Microsoft.Sql", "Microsoft.Web", "Microsoft.AzureActiveDirectory"], # DevOps
  }
}

# Create a NSG with an explict deny at 4096, since this environment needs 5 NSGs, count is set to 5
module "nsg" {
  source   = "registry.terraform.io/libre-devops/nsg/azurerm"
  count    = 1
  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  nsg_name  = "nsg-${var.short}-${var.loc}-${terraform.workspace}-${format("%02d", count.index + 1)}" // nsg-ldo-euw-dev-01 - the format("%02d") applies number padding e.g 1 = 01, 2 = 02
  subnet_id = element(values(module.network.subnets_ids), count.index)
}

resource "azurerm_network_security_rule" "vnet_inbound" {
  count = 1 # can't use length() of subnet ids as not known till apply

  name                        = "AllowVnetInbound"
  priority                    = "149"
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = module.rg.rg_name
  network_security_group_name = module.nsg[count.index].nsg_name
}

resource "azurerm_network_security_rule" "bastion_inbound" {
  count = 1 # can't use length() of subnet ids as not known till apply

  name                        = "AllowSSHRDPInbound"
  priority                    = "150"
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["22", "3389"]
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = module.rg.rg_name
  network_security_group_name = module.nsg[count.index].nsg_name
}
