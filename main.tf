terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }

  required_version = ">= 1.5.0"
}

provider "azurerm" {
  features {}
}

#####################
# Resource Group
#####################
resource "azurerm_resource_group" "rg" {
  name     = "DevOps"
  location = "East US"
}

#####################
# Storage Account for Function App
#####################
resource "azurerm_storage_account" "funcsa" {
  name                     = "azurefuncsa1234" # must be globally unique
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

#####################
# Cosmos DB Account
#####################
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = "azurebecosmos1234" # must be globally unique
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  capabilities {
    name = "EnableTable"
  }

  geo_location {
    location          = azurerm_resource_group.rg.location
    failover_priority = 0
  }
}

#####################
# Cosmos DB Table
#####################
resource "azurerm_cosmosdb_table" "counter_table" {
  name                = "counter"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  throughput          = 400

  partition_key {
    name = "PartitionKey"
    type = "String"
    kind = "Hash"
  }
}

#####################
# App Service Plan (Linux Function App)
#####################
resource "azurerm_service_plan" "function_plan" {
  name                = "function-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  os_type  = "Linux"
  sku_name = "Y1"  # Consumption Plan
}

#####################
# Linux Function App
#####################
resource "azurerm_linux_function_app" "function_app" {
  name                = "visitor-counter-func"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.function_plan.id
  storage_account_name       = azurerm_storage_account.funcsa.name
  storage_account_access_key = azurerm_storage_account.funcsa.primary_access_key
  version                   = "~4"
  site_config {
    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    "AzureWebJobsStorage"     = azurerm_storage_account.funcsa.primary_connection_string
    "FUNCTIONS_WORKER_RUNTIME" = "python"
    "COSMOS_TABLE_ENDPOINT"   = azurerm_cosmosdb_account.cosmos.endpoint
    "COSMOS_TABLE_KEY"        = azurerm_cosmosdb_account.cosmos.primary_master_key
    "TABLE_NAME"              = azurerm_cosmosdb_table.counter_table.name
  }
}
