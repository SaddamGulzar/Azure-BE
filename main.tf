terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

# ------------------------
# Configuration / locals
# ------------------------
locals {
  project_name = "azure-be"          # name requested by you
  location     = "canadacentral"     # Canada Central
  rg_name      = "DevOps"            # you said this resource group already exists
  table_name   = "counter"
  function_plan_name = "${local.project_name}-plan"
  storage_account_name = lower("${local.project_name}st") # storage name must be lowercase and unique-ish
}

# ------------------------
# Get existing resource group
# ------------------------
data "azurerm_resource_group" "rg" {
  name = local.rg_name
}

# ------------------------
# Storage account for Function App
# ------------------------
resource "azurerm_storage_account" "funcsa" {
  name                     = local.storage_account_name
  resource_group_name      = data.azurerm_resource_group.rg.name
  location                 = local.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_blob_public_access = false
}

# Get primary connection string for storage (for function app)
data "azurerm_storage_account_primary_connection_string" "funcsa_conn" {
  name                = azurerm_storage_account.funcsa.name
  resource_group_name = data.azurerm_resource_group.rg.name
}

# ------------------------
# Cosmos DB account (Table API)
# ------------------------
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = local.project_name
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name
  offer_type          = "Standard"
  consistency_policy {
    consistency_level = "Session"
  }

  # For Table API
  capabilities {
    name = "EnableTable"
  }

  geo_location {
    location          = local.location
    failover_priority = 0
  }

  # Minimal secure defaults
  enable_automatic_failover = false
  is_virtual_network_filter_enabled = false
}

# Cosmos DB Table (Table API)
resource "azurerm_cosmosdb_table" "counter_table" {
  name                = local.table_name
  resource_group_name = data.azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  throughput          = 400
}

# Retrieve keys / endpoint to pass to function app
data "azurerm_cosmosdb_account_keys" "keys" {
  name                = azurerm_cosmosdb_account.cosmos.name
  resource_group_name = data.azurerm_resource_group.rg.name
}

# Compose the Table endpoint (Cosmos Table endpoint)
# Cosmos Table REST endpoint pattern: https://{account_name}.table.cosmos.azure.com
locals {
  cosmos_table_endpoint = "https://${azurerm_cosmosdb_account.cosmos.name}.table.cosmos.azure.com"
  cosmos_table_key      = data.azurerm_cosmosdb_account_keys.keys.primary_master_key
}

# ------------------------
# App Service Plan (Consumption)
# ------------------------
resource "azurerm_app_service_plan" "function_plan" {
  name                = local.function_plan_name
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name

  kind = "FunctionApp"

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

# ------------------------
# Function App
# ------------------------
resource "azurerm_function_app" "function" {
  name                       = local.project_name
  location                   = local.location
  resource_group_name        = data.azurerm_resource_group.rg.name
  app_service_plan_id        = azurerm_app_service_plan.function_plan.id
  storage_account_name       = azurerm_storage_account.funcsa.name
  storage_account_access_key = azurerm_storage_account.funcsa.primary_access_key
  version                    = "~4"   # Azure Functions runtime version - adjust if needed
  os_type                    = "windows" # keep simple; change to linux & azurerm_linux_function_app if you prefer Linux

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "python"                         # update to "node" if using node
    "AzureWebJobsStorage"      = data.azurerm_storage_account_primary_connection_string.funcsa_conn.connection_string
    "COSMOS_TABLE_ENDPOINT"    = local.cosmos_table_endpoint
    "COSMOS_TABLE_KEY"         = local.cosmos_table_key
    "TABLE_NAME"               = local.table_name
  }

  # optional: enable FTPS deployment
  site_config {
    scm_type = "LocalGit"
  }
}

# ------------------------
# Outputs
# ------------------------
output "function_app_name" {
  value = azurerm_function_app.function.name
}

output "function_default_hostname" {
  value = azurerm_function_app.function.default_hostname
}

output "cosmos_table_endpoint" {
  value = local.cosmos_table_endpoint
}

output "cosmos_table_primary_key" {
  value = local.cosmos_table_key
  sensitive = true
}
