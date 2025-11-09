terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0"
    }
  }
}

# -----------------------------
# Provider configuration
# -----------------------------
provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
}

# -----------------------------
# Variables
# -----------------------------
variable "subscription_id" {}
variable "tenant_id" {}
variable "client_id" {}
variable "client_secret" {}

# -----------------------------
# Existing Resource Group
# -----------------------------
data "azurerm_resource_group" "devops" {
  name = "DevOps"
}

# -----------------------------
# Storage Account for Function App
# -----------------------------
resource "azurerm_storage_account" "funcsa" {
  name                     = "azurebefuncsa"
  resource_group_name      = data.azurerm_resource_group.devops.name
  location                 = data.azurerm_resource_group.devops.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"
}

# -----------------------------
# Cosmos DB Account (Table API)
# -----------------------------
resource "azurerm_cosmosdb_account" "db" {
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

# -----------------------------
# Cosmos DB Table
# -----------------------------
resource "azurerm_cosmosdb_table" "table" {
  name                = "counter"
  resource_group_name = data.azurerm_resource_group.devops.name
  account_name        = azurerm_cosmosdb_account.db.name
}

# -----------------------------
# Service Plan for Function App
# -----------------------------
resource "azurerm_service_plan" "function_plan" {
  name                = "azure-be-plan"
  location            = data.azurerm_resource_group.devops.location
  resource_group_name = data.azurerm_resource_group.devops.name
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption Plan
}

# -----------------------------
# Linux Function App
# -----------------------------
resource "azurerm_linux_function_app" "function_app" {
  name                       = "azure-be"
  location                   = data.azurerm_resource_group.devops.location
  resource_group_name        = data.azurerm_resource_group.devops.name
  service_plan_id            = azurerm_service_plan.function_plan.id
  storage_account_name       = azurerm_storage_account.funcsa.name
  storage_account_access_key = azurerm_storage_account.funcsa.primary_access_key
  functions_extension_version = "~4"

  site_config {
    application_stack {
      python_version = "3.10"
    }
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"       = "python"
    "AzureWebJobsStorage"            = azurerm_storage_account.funcsa.primary_connection_string
    "TABLE_NAME"                     = azurerm_cosmosdb_table.table.name
    "COSMOS_TABLE_ENDPOINT"          = azurerm_cosmosdb_account.db.endpoint
    "COSMOS_TABLE_CONNECTION_STRING" = "DefaultEndpointsProtocol=https;AccountName=${azurerm_cosmosdb_account.db.name};AccountKey=${azurerm_cosmosdb_account.db.primary_key};TableEndpoint=${azurerm_cosmosdb_account.db.endpoint};"
  }
}
