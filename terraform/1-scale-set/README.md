## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_application_security_group.example_asg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_security_group) | resource |
| [azurerm_resource_group.example_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_key_vault.mgmt_kv](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) | data source |
| [azurerm_key_vault_secret.mgmt_local_admin_pwd](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_resource_group.mgmt_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_ssh_public_key.mgmt_ssh_key](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/ssh_public_key) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_AZURE_BACKEND_SA_KEY"></a> [AZURE\_BACKEND\_SA\_KEY](#input\_AZURE\_BACKEND\_SA\_KEY) | This is passed as an environment variable, it is for the state backend storage | `string` | n/a | yes |
| <a name="input_AZURE_BACKEND_SA_NAME"></a> [AZURE\_BACKEND\_SA\_NAME](#input\_AZURE\_BACKEND\_SA\_NAME) | This is passed as an environment variable, it is for the state backend storage | `string` | n/a | yes |
| <a name="input_AZURE_CLIENT_ID"></a> [AZURE\_CLIENT\_ID](#input\_AZURE\_CLIENT\_ID) | This is passed as an environment variable, it is for the client ID of the service principle | `string` | n/a | yes |
| <a name="input_AZURE_CLIENT_SECRET"></a> [AZURE\_CLIENT\_SECRET](#input\_AZURE\_CLIENT\_SECRET) | This is passed as an environment variable, it is for the client secret of the service principle | `string` | n/a | yes |
| <a name="input_AZURE_SUBSCRIPTION_ID"></a> [AZURE\_SUBSCRIPTION\_ID](#input\_AZURE\_SUBSCRIPTION\_ID) | This is passed as an environment variable, it is for the target subscription | `string` | n/a | yes |
| <a name="input_AZURE_TENANT_ID"></a> [AZURE\_TENANT\_ID](#input\_AZURE\_TENANT\_ID) | n/a | `string` | `"This is passed as an environment variable, it is for the Azure tenant ID"` | no |
| <a name="input_env"></a> [env](#input\_env) | This is passed as an environment variable, it is for the shorthand environment tag for resource.  For example, production = prod | `string` | n/a | yes |
| <a name="input_loc"></a> [loc](#input\_loc) | The shorthand name of the Azure location, for example, for UK South, use uks.  For UK West, use ukw | `string` | n/a | yes |
| <a name="input_regions"></a> [regions](#input\_regions) | Long-hand names of regions in terraform | `map(string)` | <pre>{<br>  "eus": "East US",<br>  "euw": "West Europe",<br>  "uks": "UK South",<br>  "ukw": "UK West"<br>}</pre> | no |
| <a name="input_short"></a> [short](#input\_short) | This is passed as an environment variable, it is for a shorthand name for the environment, for example hello-world = hw | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_non_sensitive"></a> [non\_sensitive](#output\_non\_sensitive) | A non sensitive value |
| <a name="output_sensitive"></a> [sensitive](#output\_sensitive) | Sensitive |
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_linux_scale_set"></a> [linux\_scale\_set](#module\_linux\_scale\_set) | registry.terraform.io/libre-devops/linux-vm-scale-sets/azurerm | n/a |

## Resources

| Name | Type |
|------|------|
| [azurerm_client_config.current_creds](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_key_vault.mgmt_kv](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) | data source |
| [azurerm_key_vault_secret.mgmt_local_admin_pwd](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_network_security_group.nsg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/network_security_group) | data source |
| [azurerm_resource_group.mgmt_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_resource_group.rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_shared_image.shared_image](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/shared_image) | data source |
| [azurerm_shared_image_gallery.share_image_gallery](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/shared_image_gallery) | data source |
| [azurerm_ssh_public_key.mgmt_ssh_key](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/ssh_public_key) | data source |
| [azurerm_subnet.subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subnet) | data source |
| [azurerm_user_assigned_identity.mgmt_user_assigned_id](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/user_assigned_identity) | data source |
| [azurerm_virtual_network.vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_Regions"></a> [Regions](#input\_Regions) | Converts shorthand name to longhand name via lookup on map list | `map(string)` | <pre>{<br>  "eus": "East US",<br>  "euw": "West Europe",<br>  "uks": "UK South",<br>  "ukw": "UK West"<br>}</pre> | no |
| <a name="input_env"></a> [env](#input\_env) | This is passed as an environment variable, it is for the shorthand environment tag for resource.  For example, production = prod | `string` | `"dev"` | no |
| <a name="input_loc"></a> [loc](#input\_loc) | The shorthand name of the Azure location, for example, for UK South, use uks.  For UK West, use ukw. Normally passed as TF\_VAR in pipeline | `string` | `"euw"` | no |
| <a name="input_short"></a> [short](#input\_short) | This is passed as an environment variable, it is for a shorthand name for the environment, for example hello-world = hw | `string` | `"ldo"` | no |

## Outputs

No outputs.
