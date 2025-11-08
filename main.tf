terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.0"
    }
  }
  required_version = ">=1.7.7"
}

provider "azurerm" {
  features {}
}

# -------------------
# Resource Group
# -------------------
resource "azurerm_resource_group" "rg" {
  name     = "DevOps"
  location = "East US"
}

# -------------------
# Storage Account
# -------------------
resource "azurerm_storage_account" "funcsa" {
  name                     = "azurebefuncsa"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# -------------------
# Cosmos DB Account
# -------------------
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = "azurebecosmos"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = "MongoDB"   # For table API, you can also use Table or SQL API
  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.rg.location
    failover_priority = 0
  }
}

# -------------------
# Cosmos DB Table (for Table API)
# -------------------
resource "azurerm_cosmosdb_table" "counter_table" {
  name                = "counter"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  throughput          = 400

  # Use partition_key as a string (Terraform v3.x does NOT support 'schema' block)
  partition_key_path = "/PartitionKey"
}

# -------------------
# App Service Plan (Linux)
# -------------------
resource "azurerm_service_plan" "function_plan" {
  name                = "azure-be-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"        # Required argument
  sku_name            = "Y1"           # Consumption plan for Functions
  kind                = "FunctionApp"
  reserved            = true
}

# -------------------
# Linux Function App
# -------------------
resource "azurerm_linux_function_app" "function_app" {
  name                = "azure-be"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.function_plan.id
  storage_account_name        = azurerm_storage_account.funcsa.name
  storage_account_access_key  = azurerm_storage_account.funcsa.primary_access_key

  site_config {
    linux_fx_version = "Python|3.11"
    app_settings = {
      FUNCTIONS_WORKER_RUNTIME = "python"
      COSMOS_TABLE_ENDPOINT    = azurerm_cosmosdb_account.cosmos.endpoint
      COSMOS_TABLE_KEY         = azurerm_cosmosdb_account.cosmos.primary_master_key
      TABLE_NAME               = azurerm_cosmosdb_table.counter_table.name
    }
  }
}
