#!/usr/bin/env bash
# Pulls the config template, runner tokens and worker credentials from Key Vault (managed
# identity via IMDS, no az CLI) and writes /etc/gitlab-runner/config.toml.
#
# Exits non-zero while any required secret is missing; the systemd unit retries every
# 60s, so storing the runner tokens in Key Vault is enough to bring the runners online.
#
# After `terraform apply` or a token rotation:  sudo systemctl restart runner-config-render
# gitlab-runner hot-reloads config.toml; [runners.autoscaler] changes other than the
# policy only apply after `sudo systemctl restart gitlab-runner` (do it while idle).
set -euo pipefail

VAULT="${key_vault_name}"
CLIENT_ID="${client_id}"
CONFIG=/etc/gitlab-runner/config.toml
read -ra SECRETS <<<"runner-config-template ${required_secrets}"

token=$(curl -sf -H Metadata:true \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net&client_id=$${CLIENT_ID}" |
  jq -r .access_token)

get_secret() {
  curl -s -H "Authorization: Bearer $${token}" \
    "https://$${VAULT}.vault.azure.net/secrets/$1?api-version=7.4" | jq -r '.value // empty'
}

declare -A values
missing=()
for name in "$${SECRETS[@]}"; do
  v=$(get_secret "$${name}")
  if [ -z "$${v}" ]; then
    missing+=("$${name}")
  else
    values["$${name}"]="$${v}"
  fi
done

if [ "$${#missing[@]}" -gt 0 ]; then
  echo "waiting for Key Vault secrets: $${missing[*]}" >&2
  exit 1
fi

umask 077
mkdir -p /etc/gitlab-runner
printf '%s\n' "$${values["worker-ssh-private-key"]}" >/etc/gitlab-runner/worker_ssh_key

# Substitute in Python so tokens/passwords are never interpreted by sed or the shell.
export CONFIG_TEMPLATE="$${values["runner-config-template"]}"
export RUNNER_TOKEN_LINUX="$${values["runner-token-linux"]}"
export RUNNER_TOKEN_WINDOWS="$${values["runner-token-windows"]:-}"
export WORKER_WINDOWS_PASSWORD="$${values["worker-windows-password"]:-}"
python3 - "$${CONFIG}.new" <<'PY'
import os, sys
text = os.environ["CONFIG_TEMPLATE"]
for key in ("RUNNER_TOKEN_LINUX", "RUNNER_TOKEN_WINDOWS", "WORKER_WINDOWS_PASSWORD"):
    text = text.replace(f"__{key}__", os.environ.get(key, ""))
with open(sys.argv[1], "w") as fh:
    fh.write(text)
PY

if [ -f "$${CONFIG}" ] && cmp -s "$${CONFIG}.new" "$${CONFIG}"; then
  rm -f "$${CONFIG}.new"
  echo "config unchanged"
else
  mv "$${CONFIG}.new" "$${CONFIG}"
  echo "config written"
fi

FLEETING_PLUGIN_PATH=/opt/fleeting/plugins gitlab-runner fleeting --config "$${CONFIG}" install

# First boot: start the service. Later runs rely on hot reload so running jobs survive.
if ! systemctl is-active --quiet gitlab-runner; then
  systemctl start gitlab-runner
fi
