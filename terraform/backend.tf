terraform {
  backend "azurerm" {
    resource_group_name  = "rg-rup-ref-dev-we-01"
    storage_account_name = "stpruprefdevwe01"
    container_name       = "stblc-rup-ref-dev-terraform"
    key                  = "terraform.tfstate"
  }
}