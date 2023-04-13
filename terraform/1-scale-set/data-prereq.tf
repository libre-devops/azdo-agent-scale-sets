data "azurerm_resource_group" "rg" {
  name = "rg-${var.short}-${var.loc}-${terraform.workspace}-build"
}

data "azurerm_shared_image_gallery" "share_image_gallery" {
  name                = "gal${var.short}${var.loc}${terraform.workspace}01"
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_shared_image" "shared_image" {
  gallery_name        = data.azurerm_shared_image_gallery.share_image_gallery.name
  name                = "lbdo-azdo-ubuntu-22.04"
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.short}-${var.loc}-${terraform.workspace}-01"
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_network_security_group" "nsg" {
  name                = "nsg-${var.short}-${var.loc}-${terraform.workspace}-01"
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_subnet" "subnet" {
  name                 = "sn1-${data.azurerm_virtual_network.vnet.name}"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
}
