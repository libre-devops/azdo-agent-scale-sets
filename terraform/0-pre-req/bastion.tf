## Deploy a bastion, nsg and public IP
#module "bastion" {
#  source = "registry.terraform.io/libre-devops/bastion/azurerm"
#
#
#  vnet_rg_name = module.network.vnet_rg_name
#  vnet_name    = module.network.vnet_name
#
#  bas_subnet_iprange = "10.0.1.0/26"
#
#  bas_nsg_name     = "nsg-bas-${var.short}-${var.loc}-${terraform.workspace}-01"
#  bas_nsg_location = module.rg.rg_location
#  bas_nsg_rg_name  = module.rg.rg_name
#
#  bas_pip_name              = "pip-bas-${var.short}-${var.loc}-${terraform.workspace}-01"
#  bas_pip_location          = module.rg.rg_location
#  bas_pip_rg_name           = module.rg.rg_name
#  bas_pip_allocation_method = "Static"
#  bas_pip_sku               = "Standard"
#
#  bas_host_name          = "bas-${var.short}-${var.loc}-${terraform.workspace}-01"
#  bas_host_location      = module.rg.rg_location
#  bas_host_rg_name       = module.rg.rg_name // Deploy the bastion host to the location the scale set will be in to make IAM access tidier
#  bas_host_ipconfig_name = "bas-${var.short}-${var.loc}-${terraform.workspace}-01-ipconfig"
#
#  tags = module.rg.rg_tags
#}
