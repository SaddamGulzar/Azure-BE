terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.100"
    }
  }

  required_version = ">= 1.5.0"

  backend "local" {} # Optional: change to azurerm backend if you use remote state
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
}

# ---------------------
# Resource Group
# ---------------------
resource "azurerm_resource_group" "rg" {
  name     = "visitor-rg"
  location = "East US"
}

# ---------------------
# Storage Account (for Function App)
# ---------------------
resource "azurerm_storage_account" "storage" {
  name                     = "visitorstorage${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# ---------------------
# Cosmos DB Account
# ---------------------
resource "azurerm_cosmosdb_account" "db" {
  name                = "visitorsdb${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  capabilities {
    name = "EnableTable"
  }
}

# ---------------------
# Cosmos DB Table
# ---------------------
resource "azurerm_cosmosdb_table" "table" {
  name                = "VisitorCount"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.db.name
}

# ---------------------
# App Service Plan
# ---------------------
resource "azurerm_service_plan" "plan" {
  name                = "visitor-func-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "Y1"
}

# ---------------------
# Linux Function App
# ---------------------
resource "azurerm_linux_function_app" "function_app" {
  name                = "visitor-function-${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id
  storage_account_name       = azurerm_storage_account.storage.name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key

  site_config {
    application_stack {
      python_version = "3.10"
    }
  }

  app_settings = {
    "AzureWebJobsStorage" = azurerm_storage_account.storage.primary_connection_string
    "FUNCTIONS_WORKER_RUNTIME" = "python"
    "COSMOS_TABLE_ENDPOINT"    = azurerm_cosmosdb_account.db.table_endpoint
    "COSMOS_TABLE_KEY"         = azurerm_cosmosdb_account.db.primary_key
    "COSMOS_TABLE_NAME"        = azurerm_cosmosdb_table.table.name
  }
}
