  
resource "azurerm_app_service_plan" "tfimportarticleasp" {
  name                = var.appServicePlanName
  location            = var.rgLocation
  resource_group_name = var.rgName

  sku {
    tier = "Standard"
    size = "S1"
  }
  kind                = "Linux"
  reserved            = true
  
}

resource "azurerm_app_service" "tfimportarticle" {
  name                = var.appServiceName
  location            = var.rgLocation
  resource_group_name = var.rgName
  app_service_plan_id = azurerm_app_service_plan.tfimportarticleasp.id

  site_config {
      linux_fx_version ="DOTNETCORE|3.1"
  }

}