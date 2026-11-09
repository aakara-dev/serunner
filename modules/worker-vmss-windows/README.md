# worker-vmss-windows

Uniform Windows Server 2022 VMSS at 0 instances for the instance executor. A CustomScriptExtension enables WinRM and installs Git, gitlab-runner and VS Build Tools (.NET Framework 4.8).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.9 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 5.12.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | ~> 5.12.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_windows_virtual_machine_scale_set.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine_scale_set) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password) | Local admin password (generated in the root module, passed to the manager via custom data). | `string` | n/a | yes |
| <a name="input_admin_username"></a> [admin\_username](#input\_admin\_username) | Local admin the WinRM connector logs in as. | `string` | `"runner"` | no |
| <a name="input_computer_name_prefix"></a> [computer\_name\_prefix](#input\_computer\_name\_prefix) | Hostname prefix (Windows: max 9 chars). | `string` | `"ciwin"` | no |
| <a name="input_git_installer"></a> [git\_installer](#input\_git\_installer) | Pinned Git for Windows installer URL and SHA256. | <pre>object({<br/>    url    = string<br/>    sha256 = string<br/>  })</pre> | n/a | yes |
| <a name="input_image"></a> [image](#input\_image) | Marketplace image for workers. | <pre>object({<br/>    publisher = string<br/>    offer     = string<br/>    sku       = string<br/>    version   = string<br/>  })</pre> | <pre>{<br/>  "offer": "WindowsServer",<br/>  "publisher": "MicrosoftWindowsServer",<br/>  "sku": "2022-datacenter-azure-edition",<br/>  "version": "latest"<br/>}</pre> | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Scale set name. Must be dedicated to one [[runners]] entry. | `string` | n/a | yes |
| <a name="input_os_disk_size_gb"></a> [os\_disk\_size\_gb](#input\_os\_disk\_size\_gb) | OS disk size (Windows images need at least 127 GB). | `number` | `128` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Resource group for the scale set. | `string` | n/a | yes |
| <a name="input_runner_binary"></a> [runner\_binary](#input\_runner\_binary) | Pinned gitlab-runner Windows binary URL and SHA256 (same version as the manager). | <pre>object({<br/>    url    = string<br/>    sha256 = string<br/>  })</pre> | n/a | yes |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | Worker subnet ID. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource. | `map(string)` | `{}` | no |
| <a name="input_use_spot"></a> [use\_spot](#input\_use\_spot) | Use Spot priority (cheaper, may be evicted mid-job). | `bool` | `false` | no |
| <a name="input_vm_size"></a> [vm\_size](#input\_vm\_size) | Worker VM size. | `string` | `"Standard_D4s_v5"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_admin_username"></a> [admin\_username](#output\_admin\_username) | Username the WinRM connector uses. |
| <a name="output_id"></a> [id](#output\_id) | Scale set resource ID. |
| <a name="output_name"></a> [name](#output\_name) | Scale set name (fleeting plugin\_config.name). |
<!-- END_TF_DOCS -->
