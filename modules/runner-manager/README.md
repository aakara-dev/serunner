# runner-manager

Always-on B1ms Ubuntu VM (private IP only) running GitLab Runner with fleeting-plugin-azure. cloud-init writes config.toml and the worker SSH key from custom data. A user-assigned identity scales the worker scale sets (roles scoped to each scale set, plus subnet join).

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
| [azurerm_linux_virtual_machine.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine) | resource |
| [azurerm_network_interface.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) | resource |
| [azurerm_role_assignment.scale_sets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.subnet_join](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_user_assigned_identity.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_admin_ssh_public_key"></a> [admin\_ssh\_public\_key](#input\_admin\_ssh\_public\_key) | Your OpenSSH public key for break-glass access (no inbound SSH is open; use run-command or serial console). | `string` | n/a | yes |
| <a name="input_fleeting_plugin_version"></a> [fleeting\_plugin\_version](#input\_fleeting\_plugin\_version) | Exact fleeting-plugin-azure version (plugin = "azure:<version>"). | `string` | n/a | yes |
| <a name="input_gitlab_url"></a> [gitlab\_url](#input\_gitlab\_url) | GitLab instance URL, e.g. https://gitlab.example.com. | `string` | n/a | yes |
| <a name="input_linux"></a> [linux](#input\_linux) | Linux docker-autoscaler runner settings. | <pre>object({<br/>    vmss_name             = string<br/>    admin_username        = string<br/>    default_image         = string<br/>    privileged            = bool<br/>    capacity_per_instance = number<br/>    max_use_count         = number<br/>    max_instances         = number<br/>    idle_time             = string<br/>  })</pre> | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | Azure region. | `string` | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Short prefix used in resource and runner names. | `string` | n/a | yes |
| <a name="input_private_ip_address"></a> [private\_ip\_address](#input\_private\_ip\_address) | Static private IP for the manager; the worker NSG allows SSH/WinRM only from it. | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Resource group for the manager VM and its identity. | `string` | n/a | yes |
| <a name="input_runner_binary"></a> [runner\_binary](#input\_runner\_binary) | Pinned gitlab-runner Linux binary URL and SHA256. | <pre>object({<br/>    url    = string<br/>    sha256 = string<br/>  })</pre> | n/a | yes |
| <a name="input_runner_token_linux"></a> [runner\_token\_linux](#input\_runner\_token\_linux) | glrt- authentication token of the Linux runner. | `string` | n/a | yes |
| <a name="input_runner_token_windows"></a> [runner\_token\_windows](#input\_runner\_token\_windows) | glrt- authentication token of the Windows runner; empty when Windows is disabled. | `string` | `""` | no |
| <a name="input_scale_set_ids"></a> [scale\_set\_ids](#input\_scale\_set\_ids) | Worker scale set IDs the manager identity may scale, keyed by a static name (linux, windows). | `map(string)` | n/a | yes |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | Runner subnet ID (shared with the workers). | `string` | n/a | yes |
| <a name="input_subscription_id"></a> [subscription\_id](#input\_subscription\_id) | Subscription that holds the worker scale sets. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource. | `map(string)` | `{}` | no |
| <a name="input_vm_size"></a> [vm\_size](#input\_vm\_size) | Manager VM size. It only schedules jobs; B1ms (1 vCPU/2 GB) is enough. | `string` | `"Standard_B1ms"` | no |
| <a name="input_windows"></a> [windows](#input\_windows) | Windows instance-executor runner settings; null disables the Windows runner. | <pre>object({<br/>    vmss_name                = string<br/>    admin_username           = string<br/>    capacity_per_instance    = number<br/>    max_use_count            = number<br/>    max_instances            = number<br/>    idle_time                = string<br/>    instance_acquire_timeout = string<br/>  })</pre> | `null` | no |
| <a name="input_worker_ssh_private_key"></a> [worker\_ssh\_private\_key](#input\_worker\_ssh\_private\_key) | OpenSSH private key the connector uses to reach Linux workers. | `string` | n/a | yes |
| <a name="input_worker_windows_password"></a> [worker\_windows\_password](#input\_worker\_windows\_password) | Windows worker admin password for the WinRM connector; empty when Windows is disabled. | `string` | `""` | no |
| <a name="input_workers_resource_group_name"></a> [workers\_resource\_group\_name](#input\_workers\_resource\_group\_name) | Resource group name of the worker scale sets. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_concurrent"></a> [concurrent](#output\_concurrent) | Computed global `concurrent` value in config.toml. |
| <a name="output_identity_client_id"></a> [identity\_client\_id](#output\_identity\_client\_id) | Client ID of the manager's user-assigned identity. |
| <a name="output_identity_principal_id"></a> [identity\_principal\_id](#output\_identity\_principal\_id) | Principal ID of the manager's user-assigned identity. |
| <a name="output_vm_id"></a> [vm\_id](#output\_vm\_id) | Manager VM resource ID. |
| <a name="output_vm_name"></a> [vm\_name](#output\_vm\_name) | Manager VM name (use with `az vm run-command invoke`). |
<!-- END_TF_DOCS -->
