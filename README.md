# Azure GitLab runners that scale to zero

Autoscaling GitLab runners on Azure for a self-managed or Dedicated GitLab instance. A
small always-on manager VM runs GitLab Runner and starts worker VMs in Azure scale sets
only while jobs are queued, then removes them when idle.

| Runner tag | Executor | Workers | Use for |
|---|---|---|---|
| `linux-docker` | docker-autoscaler | Ubuntu 24.04 VMSS, D4s_v5 | Java/Maven, Scala/sbt/Spark, Python/uv, Databricks CLI, Node, .NET 6+, Terraform |
| `windows-dotnetfx` | instance (PowerShell) | Windows Server 2022 VMSS, D4s_v5 | .NET Framework builds (MSBuild, net48) |

```
GitLab <── polls ── manager VM (B1ms, always on) ── Azure API ──> VMSS linux  (0..3)
                         │  managed identity                     VMSS windows (0..1)
                         └── Key Vault: tokens, SSH key, Windows password, config template
```

## Cost (eastus, pay-as-you-go, Azure Retail Prices API, 2026-11)

| Item | Rate | Monthly at 1-5 pipelines/day |
|---|---|---|
| Manager B1ms, 24/7 | $0.0207/h | $15.11 |
| Manager disk E4 (32 GB) | $2.40/mo | $2.40 |
| Manager Standard public IP | ~$0.005/h (unverified) | ~$3.65 |
| Linux D4s_v5, about 50 h | $0.192/h; Spot $0.0405/h | $9.60; Spot $2.03 |
| Windows D4s_v5, about 10 h | $0.376/h; Spot $0.079/h | $3.76 |
| Worker disks and public IPs, only while instances exist | | under $2 |
| **Total** | | **about $30-35/mo**, or about $25 with `use_spot = true` |

For comparison, one D4s_v5 build VM running 24/7 costs about $150/mo.

The cost ceiling is `linux_max_instances` × $0.192/h, plus the same for Windows.

## Prerequisites

- Terraform `~> 1.9`, `az` CLI, and an account with Owner or User Access Administrator on the subscription (the deploy creates role assignments).
- A storage account for remote state. State contains the worker SSH key and the Windows password, so keep it private.
- Two runners created in GitLab (see step 3). You need their `glrt-` tokens.

## Deploy

```bash
# 1. Confirm the target subscription.
az account show --query '{name:name, id:id}' -o table

# 2. Configure, then plan to a file and review the plan.
cp terraform.tfvars.example terraform.tfvars   # edit: subscription_id, gitlab_url, ssh key
terraform init \
  -backend-config="resource_group_name=<tfstate-rg>" \
  -backend-config="storage_account_name=<tfstateaccount>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=gitlab-runners.tfstate" \
  -backend-config="use_azuread_auth=true"
terraform plan -out=tfplan
terraform apply tfplan
```

Expected output ends with `Apply complete!` plus `key_vault_name`, `manager_vm_name`, and the resource group names.

The apply includes a 90 s wait so the Key Vault role grant can take effect before secrets are written.

### 3. Create the runners in GitLab and store their tokens

In GitLab, go to **Group, Build, Runners, New group runner** and create two runners:

- Tags `linux-docker`. Leave "Run untagged jobs" off unless this should be the default runner.
- Tags `windows-dotnetfx`. Skip this one if `enable_windows = false`.

Copy each `glrt-…` token, then store it without it ever touching shell history or the repo:

```bash
KV=$(terraform output -raw key_vault_name)
read -rs TOKEN && az keyvault secret set --vault-name "$KV" --name runner-token-linux   --value "$TOKEN" -o none
read -rs TOKEN && az keyvault secret set --vault-name "$KV" --name runner-token-windows --value "$TOKEN" -o none
unset TOKEN
```

The manager retries every 60 s. Within a minute or two both runners show as **Online** in GitLab.

## Verify

```bash
RG_CORE=$(terraform output -raw core_resource_group)
RG_WORK=$(terraform output -raw workers_resource_group)
VM=$(terraform output -raw manager_vm_name)

# Manager health. Expect "config written" or "config unchanged", and gitlab-runner active (running).
az vm run-command invoke -g "$RG_CORE" -n "$VM" --command-id RunShellScript \
  --scripts "journalctl -u runner-config-render -n 20 --no-pager; systemctl is-active gitlab-runner; journalctl -u gitlab-runner -n 30 --no-pager" \
  --query 'value[0].message' -o tsv

# Push a pipeline that uses tags: [linux-docker], then watch an instance appear and later drop back to 0.
az vmss list-instances -g "$RG_WORK" -n "$(terraform output -raw linux_vmss_name)" -o table
```

After `linux_idle_time` (default 15m) with no jobs, `list-instances` returns no rows.

## Day-2 operations

| Task | Command / action |
|---|---|
| Change runner settings (`*_max_instances`, `*_idle_time`, images, …) | `terraform plan -out=tfplan && terraform apply tfplan`, then `az vm run-command invoke … --scripts "systemctl restart runner-config-render"`. Policy changes hot-reload. Other `[runners.autoscaler]` changes need `systemctl restart gitlab-runner` while no jobs are running. |
| Rotate a runner token | Reset it in GitLab, `az keyvault secret set …` as in step 3, then restart `runner-config-render`. |
| Upgrade GitLab Runner | Bump `runner_version` and both `runner_sha256_*` (from `https://gitlab-runner-downloads.s3.amazonaws.com/v<ver>/release.sha256`). The manager binary is installed at first boot, so replace the manager: `terraform apply -replace=module.runner_manager.azurerm_linux_virtual_machine.this`. |
| Jobs stuck "pending" | Check the runner tags match the job's `tags:`. Check `journalctl -u gitlab-runner` on the manager for `fleeting` / Azure errors (usually a missing role assignment or VMSS quota). |
| Windows job times out acquiring an instance | A cold start installs VS Build Tools (about 20-30 min). Check `C:\AzureData\bootstrap.log` on the instance through boot diagnostics or run-command. Raise `windows_instance_acquire_timeout`, or bake a Packer image. |
| Emergency stop (cost) | `az vmss scale -g "$RG_WORK" -n <vmss> --new-capacity 0`, then `systemctl stop gitlab-runner` on the manager. |

Escalation: the platform/DevOps on-call owner for the CI subscription.

## Security notes

- No inbound access from the internet. The manager has no inbound NSG rules. Workers accept SSH (22) and WinRM-HTTP (5985) only from the manager subnet.
- WinRM uses Basic auth over HTTP, which is what fleeting-plugin-azure expects. It is safe here only because of the NSG. Do not open 5985 more widely.
- The manager identity has Virtual Machine Contributor and Network Contributor on the workers resource group only, plus Key Vault Secrets User on the vault.
- Secrets never go in tfvars or the repo. Runner tokens are written straight into Key Vault. The generated SSH key and Windows password are in Key Vault and in Terraform state.

## Known limits / unverified

- `idle_count = 0` with `idle_time` is expected to delete idle instances. Confirm with the scale-in check under "Verify" after the first deploy.
- The VS Build Tools bootstrapper (`aka.ms/vs/17/release`) follows the release channel and cannot be pinned to a build.
- Worker images use `latest` marketplace versions so instances pick up OS patches.

## Layout

```
modules/network               VNet, subnets, NSGs
modules/keyvault              Key Vault, RBAC, Terraform-managed secrets
modules/runner-manager        Manager VM, identity, cloud-init, config template
modules/worker-vmss-linux     Docker worker scale set
modules/worker-vmss-windows   .NET Framework worker scale set
examples/gitlab-ci            Per-stack job templates (Java, sbt, uv, Databricks, Node, .NET, Terraform, .NET Framework)
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.9 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 5.12.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.9.1 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.14.2 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.4.2 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 5.12.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.9.1 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.4.2 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_keyvault"></a> [keyvault](#module\_keyvault) | ./modules/keyvault | n/a |
| <a name="module_network"></a> [network](#module\_network) | ./modules/network | n/a |
| <a name="module_runner_manager"></a> [runner\_manager](#module\_runner\_manager) | ./modules/runner-manager | n/a |
| <a name="module_worker_linux"></a> [worker\_linux](#module\_worker\_linux) | ./modules/worker-vmss-linux | n/a |
| <a name="module_worker_windows"></a> [worker\_windows](#module\_worker\_windows) | ./modules/worker-vmss-windows | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_resource_group.core](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_resource_group.workers](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [random_password.windows](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_string.kv_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [tls_private_key.worker](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_enable_windows"></a> [enable\_windows](#input\_enable\_windows) | Create the Windows .NET Framework pool and runner. | `bool` | `true` | no |
| <a name="input_fleeting_plugin_version"></a> [fleeting\_plugin\_version](#input\_fleeting\_plugin\_version) | fleeting-plugin-azure version, pinned exactly. | `string` | `"1.2.0"` | no |
| <a name="input_gitlab_url"></a> [gitlab\_url](#input\_gitlab\_url) | Self-managed / Dedicated GitLab URL, e.g. https://gitlab.example.com. | `string` | n/a | yes |
| <a name="input_key_vault_allowed_ip_cidrs"></a> [key\_vault\_allowed\_ip\_cidrs](#input\_key\_vault\_allowed\_ip\_cidrs) | Deployer egress CIDRs allowed to the Key Vault data plane. Empty = any network (RBAC still required). | `list(string)` | `[]` | no |
| <a name="input_linux_capacity_per_instance"></a> [linux\_capacity\_per\_instance](#input\_linux\_capacity\_per\_instance) | Concurrent jobs per Linux instance. | `number` | `2` | no |
| <a name="input_linux_default_job_image"></a> [linux\_default\_job\_image](#input\_linux\_default\_job\_image) | Image used when a job does not set `image:`. | `string` | `"alpine:3.20"` | no |
| <a name="input_linux_idle_time"></a> [linux\_idle\_time](#input\_linux\_idle\_time) | How long an idle Linux instance survives before deletion. | `string` | `"15m"` | no |
| <a name="input_linux_max_instances"></a> [linux\_max\_instances](#input\_linux\_max\_instances) | Upper bound on Linux instances (cost ceiling). | `number` | `3` | no |
| <a name="input_linux_max_use_count"></a> [linux\_max\_use\_count](#input\_linux\_max\_use\_count) | Jobs an instance may run before it is replaced (0 = unlimited). Reuse within a pipeline avoids a boot per job. | `number` | `10` | no |
| <a name="input_linux_privileged"></a> [linux\_privileged](#input\_linux\_privileged) | Run job containers privileged (needed for docker:dind / Testcontainers). | `bool` | `false` | no |
| <a name="input_linux_vm_size"></a> [linux\_vm\_size](#input\_linux\_vm\_size) | Linux worker size. | `string` | `"Standard_D4s_v5"` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region. | `string` | `"eastus"` | no |
| <a name="input_manager_admin_ssh_public_key"></a> [manager\_admin\_ssh\_public\_key](#input\_manager\_admin\_ssh\_public\_key) | Your OpenSSH public key for the manager VM (break-glass only; no inbound SSH is opened). | `string` | n/a | yes |
| <a name="input_manager_vm_size"></a> [manager\_vm\_size](#input\_manager\_vm\_size) | Runner manager VM size (always on). | `string` | `"Standard_B1ms"` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Short lowercase prefix for resource names (max 8 chars keeps the Key Vault name under 24). | `string` | `"glrun"` | no |
| <a name="input_runner_sha256_linux"></a> [runner\_sha256\_linux](#input\_runner\_sha256\_linux) | SHA256 of binaries/gitlab-runner-linux-amd64 for runner\_version (from release.sha256). | `string` | `"1c1752101f5b0f212615ad2c674d8f3499de96d9377f31aed1e3eecdbd068de1"` | no |
| <a name="input_runner_sha256_windows"></a> [runner\_sha256\_windows](#input\_runner\_sha256\_windows) | SHA256 of binaries/gitlab-runner-windows-amd64.exe for runner\_version (from release.sha256). | `string` | `"5885cb5298651080386c91dbcdff38ff5aa9de7bf7cf913eadb2bd6b8387e6c7"` | no |
| <a name="input_runner_version"></a> [runner\_version](#input\_runner\_version) | GitLab Runner version for the manager and Windows workers (keep within the GitLab server's supported range). | `string` | `"19.5.2"` | no |
| <a name="input_subscription_id"></a> [subscription\_id](#input\_subscription\_id) | Target subscription ID. Passed explicitly so the active az context cannot redirect a deploy. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Extra tags merged onto every resource. | `map(string)` | `{}` | no |
| <a name="input_use_spot"></a> [use\_spot](#input\_use\_spot) | Run worker scale sets on Spot capacity (~80% cheaper; jobs can be evicted). | `bool` | `false` | no |
| <a name="input_windows_capacity_per_instance"></a> [windows\_capacity\_per\_instance](#input\_windows\_capacity\_per\_instance) | Concurrent jobs per Windows instance (instance executor shares the host). | `number` | `1` | no |
| <a name="input_windows_git_installer"></a> [windows\_git\_installer](#input\_windows\_git\_installer) | Pinned Git for Windows installer URL and SHA256. | <pre>object({<br/>    url    = string<br/>    sha256 = string<br/>  })</pre> | <pre>{<br/>  "sha256": "4961a4a8cc778d8b6e00a5819e5fe4d078b754555aff7aedc2d77a5d74c2de80",<br/>  "url": "https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.4/Git-2.56.0.4-64-bit.exe"<br/>}</pre> | no |
| <a name="input_windows_idle_time"></a> [windows\_idle\_time](#input\_windows\_idle\_time) | Idle time before a Windows instance is deleted. Longer than Linux because cold start is ~20-30 min. | `string` | `"30m"` | no |
| <a name="input_windows_instance_acquire_timeout"></a> [windows\_instance\_acquire\_timeout](#input\_windows\_instance\_acquire\_timeout) | How long a Windows job waits for an instance (cold start includes VS Build Tools install). | `string` | `"45m"` | no |
| <a name="input_windows_max_instances"></a> [windows\_max\_instances](#input\_windows\_max\_instances) | Upper bound on Windows instances. | `number` | `1` | no |
| <a name="input_windows_max_use_count"></a> [windows\_max\_use\_count](#input\_windows\_max\_use\_count) | Jobs a Windows instance may run before it is replaced. | `number` | `20` | no |
| <a name="input_windows_vm_size"></a> [windows\_vm\_size](#input\_windows\_vm\_size) | Windows worker size. | `string` | `"Standard_D4s_v5"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_core_resource_group"></a> [core\_resource\_group](#output\_core\_resource\_group) | Resource group with network, Key Vault and manager. |
| <a name="output_key_vault_name"></a> [key\_vault\_name](#output\_key\_vault\_name) | Key Vault to store runner tokens in (runner-token-linux, runner-token-windows). |
| <a name="output_linux_vmss_name"></a> [linux\_vmss\_name](#output\_linux\_vmss\_name) | Linux worker scale set. |
| <a name="output_manager_vm_name"></a> [manager\_vm\_name](#output\_manager\_vm\_name) | Runner manager VM (for az vm run-command). |
| <a name="output_runner_concurrent"></a> [runner\_concurrent](#output\_runner\_concurrent) | Global concurrent job limit written to config.toml. |
| <a name="output_windows_vmss_name"></a> [windows\_vmss\_name](#output\_windows\_vmss\_name) | Windows worker scale set (null when disabled). |
| <a name="output_workers_resource_group"></a> [workers\_resource\_group](#output\_workers\_resource\_group) | Resource group with the worker scale sets. |
<!-- END_TF_DOCS -->
