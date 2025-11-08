terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "azurerm" {
  features {}
}

# -------------------------
# Resource Group
# -------------------------
resource "azurerm_resource_group" "rg" {
  name     = "DevOps"
  location = "East US"
}

# -------------------------
# Storage Account for Function App
# -------------------------
resource "azurerm_storage_account" "funcsa" {
  name                     = "azurebefuncsa"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# -------------------------
# Cosmos DB Account
# -------------------------
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = "azure-be"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  consistency_policy {
    consistency_level = "Session"
  }
  geo_location {
    location          = azurerm_resource_group.rg.location
    failover_priority = 0
  }
}

# -------------------------
# App Service Plan
# -------------------------
resource "azurerm_service_plan" "function_plan" {
  name                = "azure-be-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "Linux"
  reserved            = true
  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

# -------------------------
# Linux Function App
# -------------------------
resource "azurerm_linux_function_app" "function_app" {
  name                = "azure-be-func"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.function_plan.id
  storage_account_name       = azurerm_storage_account.funcsa.name
  storage_account_access_key = azurerm_storage_account.funcsa.primary_access_key
  os_type                   = "Linux"

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME   = "python"
    COSMOS_TABLE_ENDPOINT      = azurerm_cosmosdb_account.cosmos.table_endpoint
    COSMOS_TABLE_KEY           = azurerm_cosmosdb_account.cosmos.primary_key
    TABLE_NAME                 = "counter"
  }
}

# -------------------------
# Initialize Counter Table with Initial Entity
# -------------------------
resource "null_resource" "create_initial_counter" {
  depends_on = [azurerm_linux_function_app.function_app]

  provisioner "local-exec" {
    command = <<EOT
      az cosmosdb table create \
        --account-name ${azurerm_cosmosdb_account.cosmos.name} \
        --resource-group ${azurerm_resource_group.rg.name} \
        --name counter \
        --throughput 400

      az cosmosdb table entity create \
        --account-name ${azurerm_cosmosdb_account.cosmos.name} \
        --resource-group ${azurerm_resource_group.rg.name} \
        --table-name counter \
        --partition-key "counter" \
        --row-key "visitors" \
        --properties '{"count":1}'
    EOT
    interpreter = ["bash", "-c"]
  }
}
