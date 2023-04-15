module "linux_scale_set" {
  source = "registry.terraform.io/libre-devops/linux-vm-scale-sets/azurerm"

  rg_name  = data.azurerm_resource_group.rg.name
  location = data.azurerm_resource_group.rg.location
  tags     = data.azurerm_resource_group.rg.tags

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
      instances                       = 0
      overprovision                   = false
      zones                           = ["1", "2"]
      provision_vm_agent              = true

      source_image_id = data.azurerm_shared_image.shared_image.id

      os_disk = {
        storage_account_type = "StandardSSD_LRS"
        disk_size_gb         = "127"
      }

      network_interface = {
        network_security_group_id = data.azurerm_network_security_group.nsg.id

        ip_configuration = {
          subnet_id = data.azurerm_subnet.subnet.id
        }
      }

      admin_ssh_key = {
        public_key = data.azurerm_ssh_public_key.mgmt_ssh_key.public_key
      }

      automatic_os_upgrade_policy = {
        disable_automatic_rollback  = false
        enable_automatic_os_upgrade = true
      }
    }
  }
}

