# Rendered by Terraform and written by cloud-init. Edit runner settings in Terraform; a
# change replaces the manager VM.
concurrent = ${concurrent}
check_interval = 0
shutdown_timeout = 0
log_level = "info"

[[runners]]
  name = "${name_prefix}-linux-docker"
  url = "${gitlab_url}"
  token = "${runner_token_linux}"
  executor = "docker-autoscaler"
  shell = "sh"

  [runners.docker]
    image = "${linux.default_image}"
    privileged = ${linux.privileged}
    volumes = ["/cache"]

  [runners.autoscaler]
    plugin = "azure:${fleeting_plugin_version}"
    capacity_per_instance = ${linux.capacity_per_instance}
    max_use_count = ${linux.max_use_count}
    max_instances = ${linux.max_instances}
    # Docker is installed by cloud-init; don't hand the instance a job before it finishes.
    instance_ready_command = "cloud-init status --wait"

    [runners.autoscaler.plugin_config]
      name = "${linux.vmss_name}"
      subscription_id = "${subscription_id}"
      resource_group_name = "${workers_resource_group_name}"

    [runners.autoscaler.connector_config]
      username = "${linux.admin_username}"
      key_path = "/etc/gitlab-runner/worker_ssh_key"
      use_static_credentials = true
      use_external_addr = false
      timeout = "10m"

    [[runners.autoscaler.policy]]
      idle_count = 0
      idle_time = "${linux.idle_time}"
%{ if windows != null }

[[runners]]
  name = "${name_prefix}-windows-dotnetfx"
  url = "${gitlab_url}"
  token = "${runner_token_windows}"
  executor = "instance"
  shell = "powershell"
  # Manager is Linux, executor targets Windows paths.
  environment = ["FF_USE_POWERSHELL_PATH_RESOLVER=1"]

  [runners.autoscaler]
    plugin = "azure:${fleeting_plugin_version}"
    capacity_per_instance = ${windows.capacity_per_instance}
    max_use_count = ${windows.max_use_count}
    max_instances = ${windows.max_instances}
    # Cold Windows instance + VS Build Tools install takes ~20-30 min; default is 15m.
    instance_acquire_timeout = "${windows.instance_acquire_timeout}"
    instance_ready_command = 'powershell -NoProfile -Command "$n=0; while (-not (Test-Path C:\AzureData\ready)) { Start-Sleep 15; $n++; if ($n -gt 160) { exit 1 } }"'

    [runners.autoscaler.plugin_config]
      name = "${windows.vmss_name}"
      subscription_id = "${subscription_id}"
      resource_group_name = "${workers_resource_group_name}"

    [runners.autoscaler.connector_config]
      os = "windows"
      protocol = "winrm"
      username = "${windows.admin_username}"
      password = "${worker_windows_password}"
      use_static_credentials = true
      use_external_addr = false
      timeout = "10m"

    [[runners.autoscaler.policy]]
      idle_count = 0
      idle_time = "${windows.idle_time}"
%{ endif }
