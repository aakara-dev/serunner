# State holds the generated worker SSH key and Windows password, so it must live in a
# private, access-controlled storage account. Values are supplied at init time:
#
#   terraform init \
#     -backend-config="resource_group_name=<tfstate-rg>" \
#     -backend-config="storage_account_name=<tfstateaccount>" \
#     -backend-config="container_name=tfstate" \
#     -backend-config="key=gitlab-runners.tfstate" \
#     -backend-config="use_azuread_auth=true"
#
# For a local dry run without a backend: terraform init -backend=false
terraform {
  backend "azurerm" {}
}
