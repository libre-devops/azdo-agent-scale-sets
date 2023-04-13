provider "azuredevops" {
  org_service_url       = data.azurerm_key_vault_secret.azdo_url.value
  personal_access_token = data.azurerm_key_vault_secret.azdo_pat.value
}
