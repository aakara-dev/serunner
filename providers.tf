provider "azurerm" {
  features {
    key_vault {
      # Keep soft-deleted secrets recoverable; a destroy must not silently purge runner tokens.
      purge_soft_delete_on_destroy = false
    }
  }

  # Explicit so plan/apply never lands in whatever `az account` happens to be active.
  subscription_id = var.subscription_id
}
