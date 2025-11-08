azurerm_service_plan.function_plan: Creating...
azurerm_cosmosdb_account.cosmos: Creating...
azurerm_storage_account.funcsa: Creating...
╷
│ Error: a resource with the ID "/subscriptions/0bc7a085-204d-404f-a538-49b6b2ff9c1d/resourceGroups/DevOps/providers/Microsoft.Storage/storageAccounts/azurebefuncsa" already exists - to be managed via Terraform this resource needs to be imported into the State. Please see the resource documentation for "azurerm_storage_account" for more information
│ 
│   with azurerm_storage_account.funcsa,
│   on main.tf line 42, in resource "azurerm_storage_account" "funcsa":
│   42: resource "azurerm_storage_account" "funcsa" ***
│ 
╵
╷
│ Error: a resource with the ID "/subscriptions/0bc7a085-204d-404f-a538-49b6b2ff9c1d/resourceGroups/DevOps/providers/Microsoft.DocumentDB/databaseAccounts/azure-be" already exists - to be managed via Terraform this resource needs to be imported into the State. Please see the resource documentation for "azurerm_cosmosdb_account" for more information
│ 
│   with azurerm_cosmosdb_account.cosmos,
│   on main.tf line 53, in resource "azurerm_cosmosdb_account" "cosmos":
│   53: resource "azurerm_cosmosdb_account" "cosmos" ***
│ 
╵
╷
│ Error: a resource with the ID "/subscriptions/0bc7a085-204d-404f-a538-49b6b2ff9c1d/resourceGroups/DevOps/providers/Microsoft.Web/serverFarms/azure-be-plan" already exists - to be managed via Terraform this resource needs to be imported into the State. Please see the resource documentation for "azurerm_service_plan" for more information
│ 
│   with azurerm_service_plan.function_plan,
│   on main.tf line 86, in resource "azurerm_service_plan" "function_plan":
│   86: resource "azurerm_service_plan" "function_plan" ***
│ 
│ a resource with the ID
│ "/subscriptions/0bc7a085-204d-404f-a538-49b6b2ff9c1d/resourceGroups/DevOps/providers/Microsoft.Web/serverFarms/azure-be-plan"
│ already exists - to be managed via Terraform this resource needs to be
│ imported into the State. Please see the resource documentation for
│ "azurerm_service_plan" for more information
╵
Error: Terraform exited with code 1.
Error: Process completed with exit code 1.
