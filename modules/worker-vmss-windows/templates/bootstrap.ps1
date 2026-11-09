# Windows CI worker bootstrap for the GitLab Runner "instance" executor.
# Runs once per instance via the CustomScriptExtension. Installs: WinRM listener for the
# fleeting connector, Git, the pinned gitlab-runner binary (needed on the instance for
# artifacts/cache), and VS Build Tools for .NET Framework builds.
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
Start-Transcript -Path 'C:\AzureData\bootstrap.log' -Append

function Get-Verified([string]$Url, [string]$Out, [string]$Sha256) {
  Invoke-WebRequest -Uri $Url -OutFile $Out -UseBasicParsing
  if ($Sha256) {
    $actual = (Get-FileHash -Algorithm SHA256 -Path $Out).Hash.ToLower()
    if ($actual -ne $Sha256.ToLower()) { throw "Checksum mismatch for $Url" }
  }
}

# --- WinRM over HTTP with Basic auth (settings from the fleeting-plugin-azure README).
# Reachable only from the manager subnet; the NSG denies everything else.
winrm quickconfig -q
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="0"}'
winrm set winrm/config '@{MaxTimeoutms="7200000"}'
New-NetFirewallRule -DisplayName 'WinRM-HTTP-in (gitlab runner)' -Direction Inbound `
  -Protocol TCP -LocalPort 5985 -Action Allow -ErrorAction SilentlyContinue | Out-Null
# Let the local admin account get a full (non-filtered) token over remote shells.
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
  -Name LocalAccountTokenFilterPolicy -Value 1 -Type DWord

$tmp = 'C:\AzureData\dl'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

# --- Git for Windows (pinned)
Get-Verified '${git_installer_url}' "$tmp\git.exe" '${git_installer_sha256}'
Start-Process -Wait -FilePath "$tmp\git.exe" -ArgumentList '/VERYSILENT','/NORESTART','/NOCANCEL','/SP-','/SUPPRESSMSGBOXES'

# --- gitlab-runner binary (pinned, must match the manager version)
$runnerDir = 'C:\GitLab-Runner'
New-Item -ItemType Directory -Force -Path $runnerDir | Out-Null
Get-Verified '${runner_binary_url}' "$runnerDir\gitlab-runner.exe" '${runner_binary_sha256}'

# --- VS 2022 Build Tools: MSBuild + .NET Framework 4.8 targeting pack + NuGet.
# The bootstrapper URL tracks the VS 17 release channel (not pinnable to a build).
Get-Verified 'https://aka.ms/vs/17/release/vs_buildtools.exe' "$tmp\vs_buildtools.exe" ''
$vsArgs = @(
  '--quiet','--wait','--norestart','--nocache',
  '--add','Microsoft.VisualStudio.Workload.MSBuildTools',
  '--add','Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools',
  '--add','Microsoft.Net.Component.4.8.TargetingPack',
  '--add','Microsoft.VisualStudio.Component.NuGet.BuildTools',
  '--includeRecommended'
)
$p = Start-Process -Wait -PassThru -FilePath "$tmp\vs_buildtools.exe" -ArgumentList $vsArgs
# 3010 = success, reboot required; tolerated because builds work without it.
if ($p.ExitCode -notin 0, 3010) { throw "vs_buildtools failed with exit code $($p.ExitCode)" }

# --- PATH for job shells
$msbuild = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin'
$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
foreach ($d in @($runnerDir, 'C:\Program Files\Git\cmd', $msbuild)) {
  if ($machinePath -notlike "*$d*") { $machinePath = "$machinePath;$d" }
}
[Environment]::SetEnvironmentVariable('Path', $machinePath, 'Machine')

# Ready marker polled by the manager's instance_ready_command.
New-Item -ItemType File -Force -Path 'C:\AzureData\ready' | Out-Null
Remove-Item -Recurse -Force $tmp
Stop-Transcript
