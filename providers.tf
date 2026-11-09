provider "azurerm" {
  features {}

  # Explicit so plan/apply never lands in whatever `az account` happens to be active.
  subscription_id = var.subscription_id
}
