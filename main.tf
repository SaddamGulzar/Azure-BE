terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.70"
    }
  }
  required_version = ">= 1.7"
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
  name                     = "azurefuncsa1234" # must be globally unique
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Cosmos DB Account
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = "azurebecosmos1234" # must be globally unique
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level       = "Session"
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
  name                = "counter"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  database_name       = azurerm_cosmosdb_sql_database.counter_db.name

  partition_key_paths = ["/PartitionKey"]  # Must be a list
  throughput          = 400
}

# App Service Plan for Function App
resource "azurerm_service_plan" "function_plan" {
  name                = "azure-function-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Y1"  # Consumption plan
  os_type             = "Linux"
  kind                = "FunctionApp"
}

# Linux Function App
resource "azurerm_linux_function_app" "function_app" {
  name                = "azure-function-app1234"  # must be globally unique
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.function_plan.id
  storage_account_name = azurerm_storage_account.funcsa.name
  storage_account_access_key = azurerm_storage_account.funcsa.primary_access_key
  version             = "~4"

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    "COSMOS_DB_ACCOUNT" = azurerm_cosmosdb_account.cosmos.name
    "COSMOS_DB_KEY"     = azurerm_cosmosdb_account.cosmos.primary_master_key
  }
}
