terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0"
    }
  }
  required_version = ">= 1.5.0"
}

# -----------------------------
# Variables for Azure authentication
# -----------------------------
variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID"
}

variable "tenant_id" {
  type        = string
  description = "Azure Tenant ID"
}

variable "client_id" {
  type        = string
  description = "Azure Service Principal Client ID"
}

variable "client_secret" {
  type        = string
  description = "Azure Service Principal Client Secret"
  sensitive   = true
}

# -----------------------------
# Provider
# -----------------------------
provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
}

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
}

# -----------------------------
# Cosmos DB Account (Table API)
# -----------------------------
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

# -----------------------------
# Cosmos DB Table
# -----------------------------
resource "azurerm_cosmosdb_table" "table" {
  name                = "counter"
  resource_group_name = data.azurerm_resource_group.devops.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
}

# -----------------------------
# Linux Function App Service Plan
# -----------------------------
resource "azurerm_service_plan" "function_plan" {
  name                = "azure-be-plan"
  location            = "Canada Central"
  resource_group_name = data.azurerm_resource_group.devops.name
  os_type             = "Linux"
  sku_name            = "Y1"
  worker_count        = 1
}

# -----------------------------
# Function App
# -----------------------------
resource "azurerm_linux_function_app" "function_app" {
  name                       = "azure-be"
  location                   = "Canada Central"
  resource_group_name        = data.azurerm_resource_group.devops.name
  service_plan_id            = azurerm_service_plan.function_plan.id
  storage_account_name       = azurerm_storage_account.funcsa.name
  storage_account_access_key = azurerm_storage_account.funcsa.primary_access_key
  functions_extension_version = "~4"

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "python"
    "AzureWebJobsStorage"      = azurerm_storage_account.funcsa.primary_connection_string
    "COSMOS_TABLE_ENDPOINT"    = azurerm_cosmosdb_account.cosmos.endpoint
    "COSMOS_TABLE_KEY"         = azurerm_cosmosdb_account.cosmos.primary_master_key
    "TABLE_NAME"               = azurerm_cosmosdb_table.table.name
  }

  site_config {
    linux_fx_version = "Python|3.11"
  }
}

# -----------------------------
# Optional: Output Function App URL
# -----------------------------
output "function_app_url" {
  value = azurerm_linux_function_app.function_app.default_hostname
}
