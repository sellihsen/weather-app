terraform {
  backend "azurerm" {
    resource_group_name  = "rg-weather"
    storage_account_name = "storage-weather"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}