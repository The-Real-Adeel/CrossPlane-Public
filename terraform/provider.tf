terraform { //throw in the provider version and source: found at: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs, click use provider to get latest info
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.85.0"
    }
  }
}

provider "azurerm" { //select the provider in our case its Azure
  subscription_id = "ENTER ID"
  tenant_id       = "ENTER ID"
  features {}
}