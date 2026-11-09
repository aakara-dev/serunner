terraform {
  required_version = "~> 1.9"

  # Patch-level pins; .terraform.lock.hcl records the exact builds.
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.12.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.4.2"
    }
  }
}
