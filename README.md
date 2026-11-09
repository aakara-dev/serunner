# Azure GitLab runners that scale to zero

Autoscaling GitLab runners on Azure for a self-managed or Dedicated GitLab instance. A
small always-on manager VM runs GitLab Runner and starts worker VMs in Azure scale sets
only while jobs are queued, then removes them when idle.

| Runner tag | Executor | Workers | Use for |
|---|---|---|---|
| `linux-docker` | docker-autoscaler | Ubuntu 24.04 VMSS, D4s_v5 | Java/Maven, Scala/sbt/Spark, Python/uv, Databricks CLI, Node, .NET 6+, Terraform |
| `windows-dotnetfx` | instance (PowerShell) | Windows Server 2022 VMSS, D4s_v5 | .NET Framework builds (MSBuild, net48) |

```
                 hub firewall (egress allowlist)
                        ▲
GitLab <── polls ── manager VM (B1ms, always on) ── Azure API ──> VMSS linux  (0..3)
                    private IP, managed identity                 VMSS windows (0..1)
                    config.toml + SSH key via cloud-init
  all in one subnet of the existing spoke VNet, one resource group, no public IPs
```

## Cost (eastus, pay-as-you-go, Azure Retail Prices API, 2026-11)

| Item | Rate | Monthly at 1-5 pipelines/day |
|---|---|---|
| Manager B1ms, 24/7 | $0.0207/h | $15.11 |
| Manager disk E4 (32 GB) | $2.40/mo | $2.40 |
| Linux D4s_v5, about 50 h | $0.192/h; Spot $0.0405/h | $9.60; Spot $2.03 |
| Windows D4s_v5, about 10 h | $0.376/h; Spot $0.079/h | $3.76 |
| Worker disks, only while instances exist | | under $2 |
| **Total** | | **about $27-32/mo**, or about $22 with `use_spot = true`. Hub firewall traffic is billed to the hub, not here |

For comparison, one D4s_v5 build VM running 24/7 costs about $150/mo.

The cost ceiling is `linux_max_instances` × $0.192/h, plus the same for Windows.

## Prerequisites

- Terraform `~> 1.9`, `az` CLI, and an account with Owner or User Access Administrator on the subscription (the deploy creates role assignments), plus rights to create a subnet in the spoke VNet's resource group.
- A storage account for remote state. State contains the runner tokens, the worker SSH key and the Windows password, so keep it private.
- A free `/27` (minimum `/28`) in the spoke VNet:

  ```bash
  az network vnet show -g <spoke-rg> -n <spoke-vnet> \
    --query "{space:addressSpace.addressPrefixes, used:subnets[].addressPrefix}" -o json
  ```

- The spoke route table ID, copied from a subnet that already reaches GitLab (for example the AKS subnet). Leave `route_table_id` unset if Azure Policy attaches it.

  ```bash
  az network vnet subnet show -g <spoke-rg> --vnet-name <spoke-vnet> -n <aks-subnet> --query routeTable.id -o tsv
  ```

- Hub firewall rules allowing the runner subnet out to:

  | Destination | Used by |
  |---|---|
  | your GitLab URL (443) | manager polls jobs; workers clone |
  | `gitlab-runner-downloads.s3.amazonaws.com` | runner binary (manager, Windows workers) |
  | `registry.gitlab.com` | fleeting-plugin-azure install on the manager |
  | `management.azure.com`, `login.microsoftonline.com` | plugin scales the scale sets |
  | Ubuntu package mirrors (`*.ubuntu.com`, `azure.archive.ubuntu.com`) | cloud-init `docker.io`, `git` |
  | container registries your jobs use (Docker Hub: `registry-1.docker.io`, `auth.docker.io`, `production.cloudflare.docker.com`; `mcr.microsoft.com`) | job images |
  | `github.com`, `objects.githubusercontent.com`, `aka.ms`, `download.visualstudio.microsoft.com` | Windows bootstrap (Git, VS Build Tools) |

  The list is a starting point; check the firewall deny logs on the first run.

## Deploy

```bash
# 1. Create the runners in GitLab first: Group > Build > Runners > New group runner.
#    Tags `linux-docker` and `windows-dotnetfx` (skip the second if enable_windows = false).
#    Leave "Run untagged jobs" off unless this should be the default runner.

# 2. Break-glass SSH key for the manager (no inbound SSH is opened; it is for emergencies).
ssh-keygen -t rsa -b 4096 -f ~/.ssh/glrun_manager -C "glrun-manager" -N ""
export TF_VAR_manager_admin_ssh_public_key="$(cat ~/.ssh/glrun_manager.pub)"

# 3. Runner tokens, read without echo so they never reach shell history or the repo.
read -rs TF_VAR_runner_token_linux && export TF_VAR_runner_token_linux
read -rs TF_VAR_runner_token_windows && export TF_VAR_runner_token_windows

# 4. Confirm the target subscription, configure, then plan to a file and review it.
az account show --query '{name:name, id:id}' -o table
cp terraform.tfvars.example terraform.tfvars   # edit: subscription, gitlab_url, VNet, subnet, route table
terraform init \
  -backend-config="resource_group_name=<tfstate-rg>" \
  -backend-config="storage_account_name=<tfstateaccount>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=gitlab-runners.tfstate" \
  -backend-config="use_azuread_auth=true"
terraform plan -out=tfplan
terraform apply tfplan
unset TF_VAR_runner_token_linux TF_VAR_runner_token_windows
```

Expected output ends with `Apply complete!` plus `manager_vm_name`, `manager_private_ip` and `resource_group`.
Within a few minutes of first boot both runners show as **Online** in GitLab.

## Verify

```bash
RG=$(terraform output -raw resource_group)
VM=$(terraform output -raw manager_vm_name)

# Manager health. Expect cloud-init "done" and gitlab-runner "active".
az vm run-command invoke -g "$RG" -n "$VM" --command-id RunShellScript \
  --scripts "cloud-init status; systemctl is-active gitlab-runner; journalctl -u gitlab-runner -n 30 --no-pager" \
  --query 'value[0].message' -o tsv

# Push a pipeline that uses tags: [linux-docker], then watch an instance appear and later drop back to 0.
az vmss list-instances -g "$RG" -n "$(terraform output -raw linux_vmss_name)" -o table
```

After `linux_idle_time` (default 15m) with no jobs, `list-instances` returns no rows.

If cloud-init failed, `sudo tail -50 /var/log/cloud-init-output.log` (via run-command) usually shows a blocked download: add the host to the hub firewall and replace the manager.

## Day-2 operations

Runner settings and tokens travel in the manager's custom data, so changing them replaces the manager VM. The VM keeps no state, but apply while no jobs are running.

| Task | Command / action |
|---|---|
| Change runner settings (`*_max_instances`, `*_idle_time`, images, …) | `terraform plan -out=tfplan && terraform apply tfplan`. The plan shows the manager VM being replaced. |
| Rotate a runner token | Reset it in GitLab, export the new `TF_VAR_runner_token_*` as in Deploy step 3, then plan and apply. |
| Upgrade GitLab Runner | Bump `runner_version` and both `runner_sha256_*` (from `https://gitlab-runner-downloads.s3.amazonaws.com/v<ver>/release.sha256`), then plan and apply. |
| Jobs stuck "pending" | Check the runner tags match the job's `tags:`. Check `journalctl -u gitlab-runner` on the manager for `fleeting` / Azure errors (usually a missing role assignment, a firewall block on `management.azure.com`, or VMSS quota). |
| Scale-out fails with `LinkedAuthorizationFailed` | The manager identity lacks `subnets/join/action` on the runner subnet; check the `subnet_join` role assignment. |
| Windows job times out acquiring an instance | A cold start installs VS Build Tools (about 20-30 min). Check `C:\AzureData\bootstrap.log` on the instance through boot diagnostics or run-command. Raise `windows_instance_acquire_timeout`, or bake a Packer image. |
| Emergency stop (cost) | `az vmss scale -g "$RG" -n <vmss> --new-capacity 0`, then `systemctl stop gitlab-runner` on the manager. |

Escalation: the platform/DevOps on-call owner for the CI subscription.

## Security notes

- No public IPs and no inbound access from outside the subnet. Egress goes through the hub firewall.
- Manager and workers share one subnet. The NSG allows SSH (22) and WinRM-HTTP (5985) only from the manager's static private IP and denies all other inbound traffic, including from the rest of the VNet.
- WinRM uses Basic auth over HTTP, which is what fleeting-plugin-azure expects. It is safe here only because of the NSG. Do not open 5985 more widely.
- The manager identity has Virtual Machine Contributor and Network Contributor on each worker scale set only (not the resource group), plus Network Contributor on the runner subnet for `subnets/join/action`. A custom role with just `Microsoft.Network/virtualNetworks/subnets/join/action` and `.../read` would be narrower.
- Secrets never go in tfvars or the repo. Runner tokens come from `TF_VAR_*` environment variables. Tokens, the generated SSH key and the Windows password are in Terraform state and the manager's custom data (readable by root on the VM).

## Known limits / unverified

- `idle_count = 0` with `idle_time` is expected to delete idle instances. Confirm with the scale-in check under "Verify" after the first deploy.
- The VS Build Tools bootstrapper (`aka.ms/vs/17/release`) follows the release channel and cannot be pinned to a build.
- Worker images use `latest` marketplace versions so instances pick up OS patches.
- Scoping the plugin's roles to the scale sets (instead of the resource group) is not what the plugin's own test setup does. Confirm the first scale-out and scale-in under "Verify".

## Layout

```
modules/network               Runner subnet in the existing spoke VNet, route table, NSG
modules/runner-manager        Manager VM, identity, role assignments, cloud-init, config template
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
| <a name="module_network"></a> [network](#module\_network) | ./modules/network | n/a |
| <a name="module_runner_manager"></a> [runner\_manager](#module\_runner\_manager) | ./modules/runner-manager | n/a |
| <a name="module_worker_linux"></a> [worker\_linux](#module\_worker\_linux) | ./modules/worker-vmss-linux | n/a |
| <a name="module_worker_windows"></a> [worker\_windows](#module\_worker\_windows) | ./modules/worker-vmss-windows | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [random_password.windows](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [tls_private_key.worker](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_enable_windows"></a> [enable\_windows](#input\_enable\_windows) | Create the Windows .NET Framework pool and runner. | `bool` | `true` | no |
| <a name="input_fleeting_plugin_version"></a> [fleeting\_plugin\_version](#input\_fleeting\_plugin\_version) | fleeting-plugin-azure version, pinned exactly. | `string` | `"1.2.0"` | no |
| <a name="input_gitlab_url"></a> [gitlab\_url](#input\_gitlab\_url) | Self-managed / Dedicated GitLab URL, e.g. https://gitlab.example.com. | `string` | n/a | yes |
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
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Short lowercase prefix for resource names. | `string` | `"glrun"` | no |
| <a name="input_route_table_id"></a> [route\_table\_id](#input\_route\_table\_id) | Spoke route table sending 0.0.0.0/0 to the hub firewall (copy it from an existing spoke subnet). Null if Azure Policy attaches it. | `string` | `null` | no |
| <a name="input_runner_sha256_linux"></a> [runner\_sha256\_linux](#input\_runner\_sha256\_linux) | SHA256 of binaries/gitlab-runner-linux-amd64 for runner\_version (from release.sha256). | `string` | `"1c1752101f5b0f212615ad2c674d8f3499de96d9377f31aed1e3eecdbd068de1"` | no |
| <a name="input_runner_sha256_windows"></a> [runner\_sha256\_windows](#input\_runner\_sha256\_windows) | SHA256 of binaries/gitlab-runner-windows-amd64.exe for runner\_version (from release.sha256). | `string` | `"5885cb5298651080386c91dbcdff38ff5aa9de7bf7cf913eadb2bd6b8387e6c7"` | no |
| <a name="input_runner_token_linux"></a> [runner\_token\_linux](#input\_runner\_token\_linux) | glrt- token of the Linux runner. Supply as TF\_VAR\_runner\_token\_linux, never in tfvars. | `string` | n/a | yes |
| <a name="input_runner_token_windows"></a> [runner\_token\_windows](#input\_runner\_token\_windows) | glrt- token of the Windows runner (required when enable\_windows). Supply as TF\_VAR\_runner\_token\_windows. | `string` | `""` | no |
| <a name="input_runner_version"></a> [runner\_version](#input\_runner\_version) | GitLab Runner version for the manager and Windows workers (keep within the GitLab server's supported range). | `string` | `"19.5.2"` | no |
| <a name="input_subnet_prefix"></a> [subnet\_prefix](#input\_subnet\_prefix) | Free CIDR in the spoke VNet for the runner subnet. /27 recommended, /28 minimum. | `string` | n/a | yes |
| <a name="input_subscription_id"></a> [subscription\_id](#input\_subscription\_id) | Target subscription ID. Passed explicitly so the active az context cannot redirect a deploy. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Extra tags merged onto every resource. | `map(string)` | `{}` | no |
| <a name="input_use_spot"></a> [use\_spot](#input\_use\_spot) | Run worker scale sets on Spot capacity (~80% cheaper; jobs can be evicted). | `bool` | `false` | no |
| <a name="input_vnet_name"></a> [vnet\_name](#input\_vnet\_name) | Existing spoke VNet the runner subnet is created in. | `string` | n/a | yes |
| <a name="input_vnet_resource_group_name"></a> [vnet\_resource\_group\_name](#input\_vnet\_resource\_group\_name) | Resource group of the existing spoke VNet. | `string` | n/a | yes |
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
| <a name="output_linux_vmss_name"></a> [linux\_vmss\_name](#output\_linux\_vmss\_name) | Linux worker scale set. |
| <a name="output_manager_private_ip"></a> [manager\_private\_ip](#output\_manager\_private\_ip) | Manager's static private IP (source address seen by the hub firewall and GitLab). |
| <a name="output_manager_vm_name"></a> [manager\_vm\_name](#output\_manager\_vm\_name) | Runner manager VM (for az vm run-command). |
| <a name="output_resource_group"></a> [resource\_group](#output\_resource\_group) | Resource group with the manager, worker scale sets, identity and NSG. |
| <a name="output_runner_concurrent"></a> [runner\_concurrent](#output\_runner\_concurrent) | Global concurrent job limit written to config.toml. |
| <a name="output_subnet_id"></a> [subnet\_id](#output\_subnet\_id) | Runner subnet created in the spoke VNet. |
| <a name="output_windows_vmss_name"></a> [windows\_vmss\_name](#output\_windows\_vmss\_name) | Windows worker scale set (null when disabled). |
<!-- END_TF_DOCS -->
