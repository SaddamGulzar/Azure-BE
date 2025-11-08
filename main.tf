terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Existing Resource Group
data "azurerm_resource_group" "devops" {
  name = "DevOps"
}

# Storage Account
resource "azurerm_storage_account" "funcsa" {
  name                     = "azurebefuncsa"
  resource_group_name      = data.azurerm_resource_group.devops.name
  location                 = data.azurerm_resource_group.devops.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Cosmos DB Account (Table API)
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = "azure-be"
  location            = "Canada Central"
  resource_group_name = data.azurerm_resource_group.devops.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = "Canada Central"
    failover_priority = 0
  }

  capabilities {
    name = "EnableTable"
  }
}

# Cosmos DB Table
resource "azurerm_cosmosdb_table" "table" {
  name                = "counter"
  resource_group_name = data.azurerm_resource_group.devops.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
}

# Service Plan (Linux)
resource "azurerm_service_plan" "function_plan" {
  name                = "azure-be-plan"
  location            = "Canada Central"
  resource_group_name = data.azurerm_resource_group.devops.name
  os_type             = "Linux"
  sku_name            = "Y1"
  worker_count        = 1
}

# Function App
resource "azurerm_linux_function_app" "function_app" {
  name                        = "azure-be"
  location                    = "Canada Central"
  resource_group_name         = data.azurerm_resource_group.devops.name
  service_plan_id             = azurerm_service_plan.function_plan.id
  storage_account_name        = azurerm_storage_account.funcsa.name
  storage_account_access_key  = azurerm_storage_account.funcsa.primary_access_key
  functions_extension_version = "~4"

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"       = "python"
    "AzureWebJobsStorage"            = azurerm_storage_account.funcsa.primary_connection_string
    "COSMOS_TABLE_CONNECTION_STRING" = azurerm_storage_account.funcsa.primary_connection_string
    "TABLE_NAME"                     = azurerm_cosmosdb_table.table.name
  }
}
