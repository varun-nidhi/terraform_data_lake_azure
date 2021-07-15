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

resource "azurerm_storage_share" "this" {
  name                 = "sharename"
  storage_account_name = azurerm_storage_account.this.name
  quota                = 1
}

resource "azurerm_storage_share_file" "this" {
  name             = "requirements.txt"
  storage_share_id = azurerm_storage_share.this.id
  source           = "requirements.txt"
}



resource "azurerm_kubernetes_cluster" "example" {
  name = "example-aks1"
  location = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix = "exampleaks1"

  default_node_pool {
    name = "default"
    node_count = 1
    vm_size = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Production"
  }
}

provider "kubernetes" {
  alias = "existing"
  host = azurerm_kubernetes_cluster.example.kube_config.0.host
  client_certificate = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_certificate)
  client_key = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.cluster_ca_certificate)
}

resource "kubernetes_storage_class" "this" {
  provider = kubernetes.existing
  metadata {
    name = "terraform-example"
  }
  storage_provisioner = "kubernetes.io/azure-file"
  reclaim_policy      = "Retain"
  parameters = {
    type = "pd-standard"
  }
  mount_options = ["file_mode=0700", "dir_mode=0777", "mfsymlinks", "uid=1000", "gid=1000", "nobrl", "cache=none"]
}


resource "kubernetes_persistent_volume" "this" {
  provider = kubernetes.existing
  metadata {
    name = "example"
  }
  spec {
    capacity = {
      storage = "1Gi"
    }
    access_modes = ["ReadWriteMany"]
    storage_class_name = kubernetes_storage_class.this.metadata.0.name
    persistent_volume_source {
      azure_file{
        secret_name = azurerm_storage_account.this.primary_access_key
        share_name = azurerm_storage_share.this.name
      }
    }
  }
}


resource "kubernetes_persistent_volume_claim" "this" {
  provider = kubernetes.existing

  metadata {
    name = "exampleclaimname"
  }
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
    volume_name = kubernetes_persistent_volume.this.metadata.0.name
    storage_class_name = kubernetes_storage_class.this.metadata.0.name

  }
}

resource "kubernetes_config_map" "this" {
  provider = kubernetes.existing
  metadata {
    name = "requirements"
  }

  data = {

    "requirements.txt" = file("requirements.txt")
  }


}
