terraform {
  required_version = "= 0.13.7"

  required_providers {
    azurerm    = "~> 2.66.0"
    databricks = {
      source = "databrickslabs/databricks"
      version = "0.3.5"
    }
  }
}

variable "client_id" {
  type = string
}

variable "client_secret" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "subscription_id" {
  type = string
}

provider "azurerm" {
  features {}

  client_id         = var.client_id
  client_secret     = var.client_secret
  tenant_id         = var.tenant_id
  subscription_id   = var.subscription_id
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "this" {
  name     = "myrg"
  location = "North Central US"
}

resource "azurerm_storage_account" "this" {
  name                      = "mystorageaccountvarun"
  resource_group_name       = azurerm_resource_group.this.name
  location                  = azurerm_resource_group.this.location
  access_tier               = "Hot"
  account_kind              = "StorageV2"
  is_hns_enabled            = true
  account_tier              = "Standard"
  account_replication_type  = "GRS"
  enable_https_traffic_only = true
}

resource "azurerm_role_assignment" "this" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}


resource "azurerm_storage_container" "this" {
  name                  = "data"
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"
}

resource "azurerm_databricks_workspace" "this" {
  name                = "myworkspace"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "standard"
}

provider "databricks" {
  azure_workspace_resource_id = azurerm_databricks_workspace.this.id
  azure_tenant_id      = data.azurerm_client_config.current.tenant_id
  azure_client_id             = var.client_id
  azure_client_secret         = var.client_secret
}



data "databricks_node_type" "smallest" {
  local_disk = true
}

//data "databricks_spark_version" "latest_lts" {
//  long_term_support = true
//}


resource "databricks_cluster" "this" {
  cluster_name            = "Single Node"
  spark_version           =  "7.0.x-scala2.12"
  node_type_id            = "Standard_DS3_v2"
  autotermination_minutes = 20

  spark_conf = {
    # Single-node
    "spark.databricks.cluster.profile" : "singleNode"
    "spark.master" : "local[*]"
  }

  custom_tags = {
    "ResourceClass" = "SingleNode"
  }
}

resource "databricks_secret_scope" "this" {
  name = "terraform"
  initial_manage_principal = "users"
}

resource "databricks_secret" "this" {
  key          = "service_principal_key"
  string_value = var.client_secret
  scope        = databricks_secret_scope.this.name
}

resource "databricks_azure_adls_gen2_mount" "this" {
  cluster_id             = databricks_cluster.this.id
  storage_account_name   = azurerm_storage_account.this.name
  container_name         = azurerm_storage_container.this.name
  mount_name             = "data"
  tenant_id              = data.azurerm_client_config.current.tenant_id
  client_id              = data.azurerm_client_config.current.client_id
  client_secret_scope    = databricks_secret_scope.this.name
  client_secret_key      = databricks_secret.this.key
  initialize_file_system = true
}
