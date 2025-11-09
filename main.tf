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
# Variables for provider
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
# EXISTING Storage Account
# -----------------------------
data "azurerm_storage_account" "funcsa" {
  name                = "azurebefuncsa"
  resource_group_name = data.azurerm_resource_group.devops.name
}

# -----------------------------
# EXISTING Cosmos DB Account
# -----------------------------
data "azurerm_cosmosdb_account" "cosmos" {
  name                = "azure-be"
  resource_group_name = data.azurerm_resource_group.devops.name
}

# -----------------------------
# EXISTING Cosmos DB Table
# -----------------------------
data "azurerm_cosmosdb_table" "table" {
  name                = "counter"
  resource_group_name = data.azurerm_resource_group.devops.name
  account_name        = data.azurerm_cosmosdb_account.cosmos.name
}

# -----------------------------
# EXISTING Service Plan
# -----------------------------
data "azurerm_service_plan" "function_plan" {
  name                = "azure-be-plan"
  resource_group_name = data.azurerm_resource_group.devops.name
}

# -----------------------------
# Function App
# -----------------------------
resource "azurerm_linux_function_app" "function_app" {
  name                        = "azure-be"
  location                    = "Canada Central"
  resource_group_name         = data.azurerm_resource_group.devops.name
  service_plan_id             = data.azurerm_service_plan.function_plan.id
  storage_account_name        = data.azurerm_storage_account.funcsa.name
  storage_account_access_key  = data.azurerm_storage_account.funcsa.primary_access_key
  functions_extension_version = "~4"

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"         = "python"
    "AzureWebJobsStorage"              = data.azurerm_storage_account.funcsa.primary_connection_string
    "TABLE_NAME"                       = data.azurerm_cosmosdb_table.table.name
    "COSMOS_TABLE_ENDPOINT"            = data.azurerm_cosmosdb_account.cosmos.endpoint
    "COSMOS_TABLE_CONNECTION_STRING"   = "DefaultEndpointsProtocol=https;AccountName=${data.azurerm_cosmosdb_account.cosmos.name};AccountKey=${data.azurerm_cosmosdb_account.cosmos.primary_key};TableEndpoint=${data.azurerm_cosmosdb_account.cosmos.endpoint};"
  }

  site_config {
    application_stack {
      python_version = "3.10"
    }
  }
}
