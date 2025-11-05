terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform"
    storage_account_name = "blobstorageinfra"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}