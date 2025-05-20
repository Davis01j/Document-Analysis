# Terraform script to deploy secure Azure AI document processing infrastructure
# Assumes blob storage already exists and is not managed by Terraform

provider "azurerm" {
  features {}
}

variable "location" {
  default = "eastus"
}

variable "resource_group_name" {
  default = "dataproject-rg"
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "dataproject_vnet" {
  name                = "dataproject-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "dataproject_subnet" {
  name                 = "dataproject-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.dataproject_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  service_endpoints    = ["Microsoft.Storage", "Microsoft.CognitiveServices", "Microsoft.DocumentDB", "Microsoft.Web"]
}

# Azure Cosmos DB
resource "azurerm_cosmosdb_account" "dataproject_cosmos" {
  name                = "dataproject-cosmos"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  consistency_policy {
    consistency_level = "Session"
  }
  geo_location {
    location          = var.location
    failover_priority = 0
  }
  enable_free_tier = true
  is_virtual_network_filter_enabled = true
  virtual_network_rules {
    id = azurerm_subnet.dataproject_subnet.id
  }
}

# Azure Cognitive Search
resource "azurerm_search_service" "dataproject_search" {
  name                = "dataproject-search"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "basic"
  replica_count       = 1
  partition_count     = 1
  hosting_mode        = "default"
  identity {
    type = "SystemAssigned"
  }
}

# Azure OpenAI (Cognitive Services)
resource "azurerm_cognitive_account" "dataproject_openai" {
  name                = "dataproject-openai"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  kind                = "OpenAI"
  sku_name            = "S0"
  identity {
    type = "SystemAssigned"
  }
  network_acls {
    default_action = "Deny"
    virtual_network_rules {
      subnet_id = azurerm_subnet.dataproject_subnet.id
    }
    ip_rules = []
  }
}

# Azure Function App (for orchestration)
resource "azurerm_storage_account" "dataproject_func_storage" {
  name                     = "dataprojectfuncsa"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_app_service_plan" "dataproject_plan" {
  name                = "dataproject-plan"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  kind                = "FunctionApp"
  reserved            = true
  sku {
    tier = "ElasticPremium"
    size = "EP1"
  }
}

resource "azurerm_linux_function_app" "dataproject_func" {
  name                       = "dataproject-func"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  service_plan_id            = azurerm_app_service_plan.dataproject_plan.id
  storage_account_name       = azurerm_storage_account.dataproject_func_storage.name
  storage_account_access_key = azurerm_storage_account.dataproject_func_storage.primary_access_key
  site_config {
    always_on = true
  }
  identity {
    type = "SystemAssigned"
  }
  virtual_network_subnet_id = azurerm_subnet.dataproject_subnet.id
}

# Outputs
output "cosmosdb_uri" {
  value = azurerm_cosmosdb_account.dataproject_cosmos.endpoint
}

output "search_service_name" {
  value = azurerm_search_service.dataproject_search.name
}

output "openai_endpoint" {
  value = azurerm_cognitive_account.dataproject_openai.endpoint
} 
