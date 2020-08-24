terraform {
  backend "azurerm" {
    storage_account_name = "001terraformstatefile"
    container_name       = "state"
    key                  = "sbx.terraform.tfstate"
  }
}

provider "azurerm" {
  version = "=2.0.0"
  features {}
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

resource "azurerm_resource_group" "tfimportarticle" {
  name     = "tfimportarticle"
  location = "West Europe"
}

module "tfimportarticle_webapp" {
  source = "./modules/appService"

  rgName = azurerm_resource_group.tfimportarticle.name

  rgLocation = azurerm_resource_group.tfimportarticle.location

  appServiceName = "tfimportarticle01"
  
  appServicePlanName = "tfimportarticleasp01"

}