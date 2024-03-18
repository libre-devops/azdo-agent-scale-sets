module "shared_vars" {
  source = "libre-devops/shared-vars/azurerm"
}

locals {
  lookup_cidr = {
    for landing_zone, envs in module.shared_vars.cidrs : landing_zone => {
      for env, cidr in envs : env => cidr
    }
  }
}

module "subnet_calculator" {
  source = "libre-devops/subnet-calculator/null"

  base_cidr    = local.lookup_cidr[var.short][var.env][0]
  subnet_sizes = [26, 26]
}

#module "bastion" {
#  source = "libre-devops/bastion/azurerm"
#
#  rg_name  = data.azurerm_resource_group.rg.name
#  location = data.azurerm_resource_group.rg.location
#  tags     = data.azurerm_resource_group.rg.tags
#
#  bastion_host_name                  = "bst-${var.short}-${var.loc}-${var.env}-01"
#  create_bastion_nsg                 = true
#  create_bastion_nsg_rules           = true
#  create_bastion_subnet              = true
#  bastion_subnet_target_vnet_name    = data.azurerm_virtual_network.vnet.name
#  bastion_subnet_target_vnet_rg_name = data.azurerm_virtual_network.vnet.resource_group_name
#  bastion_subnet_range               = module.subnet_calculator.subnet_ranges[1]
#}

locals {
  name = "vmss${var.short}${var.loc}${var.env}01"
}

module "azdo_spn" {
  source = "github.com/libre-devops/terraform-azuredevops-federated-managed-identity-connection"

  rg_id    = data.azurerm_resource_group.rg.id
  location = data.azurerm_resource_group.rg.location
  tags     = data.azurerm_resource_group.rg.tags

  azuredevops_organization_guid = data.azurerm_key_vault_secret.azdo_guid.value
  azuredevops_organization_name = data.azurerm_key_vault_secret.azdo_org_name.value
  azuredevops_project_name      = data.azurerm_key_vault_secret.azdo_project_name.value
}

#
#module "windows_vm_scale_set" {
#  source = "libre-devops/windows-uniform-orchestration-vm-scale-sets/azurerm"
#
#  rg_name  = data.azurerm_resource_group.rg.name
#  location = data.azurerm_resource_group.rg.location
#  tags     = data.azurerm_resource_group.rg.tags
#
#  scale_sets = [
#    {
#
#      name = local.name
#
#      computer_name_prefix            = "vmss1"
#      admin_username                  = "Local${title(var.short)}${title(var.env)}Admin"
#      admin_password                  = data.azurerm_key_vault_secret.admin_pwd.value
#      instances                       = 1
#      sku                             = "Standard_B2ms"
#      vm_os_simple                    = false
#      use_custom_image                = true
#      custom_source_image_id          = data.azurerm_shared_image.azdo_win_image.id
#      disable_password_authentication = true
#      overprovision                   = true
#      upgrade_mode                    = "Manual"
#      enable_automatic_updates        = true
#      create_asg                      = true
#
#      identity_type     = "SystemAssigned, UserAssigned"
#      identity_ids      = [module.azdo_spn.user_assigned_managed_identity_id]
#      network_interface = [
#        {
#          name                          = "nic-${local.name}"
#          primary                       = true
#          enable_accelerated_networking = false
#          ip_configuration              = [
#            {
#              name                           = "ipconfig-${local.name}"
#              primary                        = true
#              subnet_id                      = data.azurerm_subnet.subnet1.id
#              application_security_group_ids = []
#            }
#          ]
#        }
#      ]
#      os_disk = {
#        caching              = "ReadWrite"
#        storage_account_type = "StandardSSD_LRS"
#        disk_size_gb         = 127
#      }
#
#      boot_diagnostics = {
#        storage_account_uri = null
#      }
#
#      extension = []
#    }
#  ]
#}
