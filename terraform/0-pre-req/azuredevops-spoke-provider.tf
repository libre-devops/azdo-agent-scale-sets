data "azurerm_key_vault_secret" "azdo_pat" {
  key_vault_id = data.azurerm_key_vault.mgmt_kv.id
  name         = var.azdo_pat
}

data "azurerm_key_vault_secret" "azdo_url" {
  key_vault_id = data.azurerm_key_vault.mgmt_kv.id
  name         = var.azdo_url
}

provider "azuredevops" {
  org_service_url       = data.azurerm_key_vault_secret.azdo_url.value
  personal_access_token = data.azurerm_key_vault_secret.azdo_pat.value
}
