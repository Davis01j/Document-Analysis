############################################
# Terraform – Secure AI Document Pipeline  #
############################################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.29.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# ─── Variables ────────────────────────────────────────────────────────────────
# ‼️ Default region changed to West US 3
variable "location"            { default = "westus3" }
variable "resource_group_name" { default = "dataproject-rg" }

# ─── Resource Group ───────────────────────────────────────────────────────────
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# ─── Networking ───────────────────────────────────────────────────────────────
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

  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.AzureCosmosDB",
    "Microsoft.CognitiveServices",
    "Microsoft.Web"
  ]
}

# ─── Cosmos DB ────────────────────────────────────────────────────────────────
resource "azurerm_cosmosdb_account" "dataproject_cosmos" {
  name                = "dataproject-cosmos"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy { consistency_level = "Session" }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  is_virtual_network_filter_enabled = true
  virtual_network_rule { id = azurerm_subnet.dataproject_subnet.id }
}

# ─── Azure Cognitive Search ──────────────────────────────────────────────────
resource "azurerm_search_service" "dataproject_search" {
  name                = "dataproject-search"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "basic"
  replica_count       = 1
  partition_count     = 1
  hosting_mode        = "default"

  identity { type = "SystemAssigned" }
}

# ─── Azure OpenAI ─────────────────────────────────────────────────────────────
resource "azurerm_cognitive_account" "dataproject_openai" {
  name                = "dataproject-openai"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  kind                = "OpenAI"
  sku_name            = "S0"
  custom_subdomain_name = "dataproject-openai"

  identity { type = "SystemAssigned" }

  network_acls {
    default_action = "Deny"
    virtual_network_rules { subnet_id = azurerm_subnet.dataproject_subnet.id }
    ip_rules = []
  }
}

# ─── Function-App Hosting (Linux, Consumption plan) ──────────────────────────
resource "azurerm_storage_account" "dataproject_func_storage" {
  name                     = "dataprojectfuncsa"          # must be globally unique
  location                 = var.location
  resource_group_name      = azurerm_resource_group.main.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "dataproject_plan" {
  name                = "dataproject-plan"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = "Y1"                              # Consumption
}

resource "azurerm_linux_function_app" "dataproject_func" {
  name                = "dataproject-func"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  service_plan_id            = azurerm_service_plan.dataproject_plan.id
  storage_account_name       = azurerm_storage_account.dataproject_func_storage.name
  storage_account_access_key = azurerm_storage_account.dataproject_func_storage.primary_access_key

  identity { type = "SystemAssigned" }

  virtual_network_subnet_id = azurerm_subnet.dataproject_subnet.id

  site_config {
    application_stack { python_version = "3.11" }
  }
}

# ─── Outputs ────────────────────────────────────────────────────────────────
output "cosmosdb_uri"        { value = azurerm_cosmosdb_account.dataproject_cosmos.endpoint }
output "search_service_name" { value = azurerm_search_service.dataproject_search.name }
output "openai_endpoint"     { value = azurerm_cognitive_account.dataproject_openai.endpoint }