data "azurerm_resource_group" "data_rg" {
  name = "rg-${var.short}-${var.loc}-${terraform.workspace}-build"
}

module "network" {
  source = "registry.terraform.io/libre-devops/network/azurerm"

  rg_name  = data.azurerm_resource_group.data_rg.name // rg-ldo-euw-dev-build
  location = data.azurerm_resource_group.data_rg.location
  tags     = data.azurerm_resource_group.data_rg.tags

  vnet_name     = "vnet-${var.short}-${var.loc}-${terraform.workspace}-01" // vnet-ldo-euw-dev-01
  vnet_location = module.network.vnet_location

  address_space   = ["10.0.0.0/16"]
  subnet_prefixes = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  subnet_names    = ["sn1-${module.network.vnet_name}", "sn2-${module.network.vnet_name}", "sn3-${module.network.vnet_name}"] //sn1-vnet-ldo-euw-dev-01
  subnet_service_endpoints = {
    "sn1-${module.network.vnet_name}" = ["Microsoft.Storage"]                   // Adds extra subnet endpoints to sn1-vnet-ldo-euw-dev-01
    "sn2-${module.network.vnet_name}" = ["Microsoft.Storage", "Microsoft.Sql"], // Adds extra subnet endpoints to sn2-vnet-ldo-euw-dev-01
    "sn3-${module.network.vnet_name}" = ["Microsoft.AzureActiveDirectory"]      // Adds extra subnet endpoints to sn3-vnet-ldo-euw-dev-01
  }
}

module "nsg" {
  source = "registry.terraform.io/libre-devops/nsg/azurerm"

  rg_name  = data.azurerm_resource_group.data_rg.name
  location = data.azurerm_resource_group.data_rg.location
  tags     = data.azurerm_resource_group.data_rg.tags

  nsg_name  = "nsg-${var.short}-${var.loc}-${terraform.workspace}-01"
  subnet_id = element(values(module.network.subnets_ids), 0)
}

data "azurerm_shared_image_gallery" "share_image_gallery" {
  name                = "gal${var.short}${var.loc}${terraform.workspace}01"
  resource_group_name = data.azurerm_resource_group.data_rg.name
}

data "azurerm_shared_image" "shared_image" {
  gallery_name        = data.azurerm_shared_image_gallery.share_image_gallery.name
  name                = "lbdo-azdo-ubuntu-22.04"
  resource_group_name = data.azurerm_resource_group.data_rg.name
}

module "linux_scale_set" {
  source = "registry.terraform.io/libre-devops/linux-vm-scale-sets/azurerm"

  rg_name  = data.azurerm_resource_group.data_rg.name
  location = data.azurerm_resource_group.data_rg.location
  tags     = data.azurerm_resource_group.data_rg.tags

  ssh_public_key   = data.azurerm_ssh_public_key.mgmt_ssh_key.public_key
  use_simple_image = false
  identity_type    = "UserAssigned"
  identity_ids     = [data.azurerm_user_assigned_identity.mgmt_user_assigned_id.id]
  asg_name         = "asg-vmss${var.short}${var.loc}${terraform.workspace}-${var.short}-${var.loc}-${terraform.workspace}-01"
  admin_username   = "LibreDevOpsAdmin"

  settings = {
    "vmss${var.short}${var.loc}${terraform.workspace}01" = {

      sku                             = "Standard_B4ms"
      disable_password_authentication = true
      instances                       = 2
      overprovision                   = false
      zones                           = ["2"]
      provision_vm_agent              = true

      source_image_id = data.azurerm_shared_image.shared_image.id

      os_disk = {
        storage_account_type = "Standard_LRS"
        disk_size_gb         = "127"
      }

      network_interface = {
        network_security_group_id = module.nsg.nsg_id

        ip_configuration = {
          subnet_id = element(values(module.network.subnets_ids), 0)
        }
      }

      admin_ssh_key = {
        public_key = data.azurerm_ssh_public_key.mgmt_ssh_key.public_key
      }
    }
  }
}

