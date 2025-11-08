terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "DevOps"
  location = "East US"
}

# Storage Account for Function App
resource "azurerm_storage_account" "funcsa" {
  name                     = "azurebefuncsa"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Cosmos DB Account (SQL API)
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

# Cosmos DB SQL Database
resource "azurerm_cosmosdb_sql_database" "counter_db" {
  name                = "counterdb"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
}

# Cosmos DB SQL Container
resource "azurerm_cosmosdb_sql_container" "counter_container" {
  name                = "countercontainer"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  database_name       = azurerm_cosmosdb_sql_database.counter_db.name

  partition_key_path = "/PartitionKey"
  throughput         = 400
}

# App Service Plan
resource "azurerm_service_plan" "function_plan" {
  name                = "azure-be-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku_name = "Y1" # Consumption plan
  os_type  = "Linux"
}

# Linux Function App
resource "azurerm_linux_function_app" "function_app" {
  name                = "my-function-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.function_plan.id

  storage_account_name       = azurerm_storage_account.funcsa.name
  storage_account_access_key = azurerm_storage_account.funcsa.primary_access_key

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    "COSMOS_DB_KEY"  = azurerm_cosmosdb_account.cosmos.primary_key
    "COSMOS_DB_NAME" = azurerm_cosmosdb_account.cosmos.name
  }
}
