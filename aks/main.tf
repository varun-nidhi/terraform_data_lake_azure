terraform {
  required_version = "= 0.13.7"

  required_providers {
    azurerm = "~> 2.66.0"
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

  client_id = var.client_id
  client_secret = var.client_secret
  tenant_id = var.tenant_id
  subscription_id = var.subscription_id
}


resource "azurerm_resource_group" "this" {
  name = "myrg"
  location = "North Central US"
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

//output "client_certificate" {
//  value = azurerm_kubernetes_cluster.example.kube_config.0.client_certificate
//}
//
//output "kube_config" {
//  value = azurerm_kubernetes_cluster.example.kube_config_raw
//}


resource "azurerm_postgresql_server" "example" {
  name = "postgresql-server-2-varun30"
  location = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  sku_name = "B_Gen5_2"

  storage_mb = 5120
  backup_retention_days = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled = true

  administrator_login = "psqladminun"
  administrator_login_password = "H@Sh1CoR3!"
  version = "9.5"
  ssl_enforcement_enabled = false

}

resource "azurerm_postgresql_firewall_rule" "example" {
  name                = "office"
  resource_group_name = azurerm_resource_group.this.name
  server_name         = azurerm_postgresql_server.example.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

resource "azurerm_postgresql_database" "example" {
  name = "exampledb2"
  resource_group_name = azurerm_resource_group.this.name
  server_name = azurerm_postgresql_server.example.name
  charset = "UTF8"
  collation = "English_United States.1252"
}


# NOTE: the Name used for Redis needs to be globally unique
resource "azurerm_redis_cache" "example" {
  name = "example-cache-varun301986"
  location = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  capacity = 1
  family = "C"
  sku_name = "Standard"
  enable_non_ssl_port = true
  minimum_tls_version = "1.2"

  redis_configuration {
  }
}


provider "helm" {
  kubernetes {
    host = azurerm_kubernetes_cluster.example.kube_config.0.host
    client_certificate = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_certificate)
    client_key = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.cluster_ca_certificate)
  }
}





resource "helm_release" "airflow" {
  name = "airflow-aks11"

  repository = "https://charts.bitnami.com/bitnami"
  chart = "airflow"
  values = [
    file("values.yaml")]
  set{
   name = "dagsConfigMap"
    value = kubernetes_config_map.dags.metadata.0.name
  }
  set {
    name = "service.type"
    value = "LoadBalancer"
  }
  set {
    name = "airflow.loadExamples"
    value = "true"
  }
  set {
    name = "loadExamples"
    value = "true"
  }
  set {
    name = "airflow.baseUrl"
    value = "http://DOMAIN"
  }
  set {
    name = "web.baseUrl"
    value = "http://DOMAIN"
  }
  set {
    name = "postgresql.enabled"
    value = "false"
  }
  set {
    name = "redis.enabled"
    value = "false"
  }
  set {
    name = "externalDatabase.host"
    value = azurerm_postgresql_server.example.fqdn
  }
  set {
    name = "externalDatabase.user"
    value = "psqladminun@${azurerm_postgresql_server.example.name}"
  }
  set {
    name = "externalDatabase.database"
    value = azurerm_postgresql_database.example.name
  }
  set {
    name = "externalDatabase.password"
    value = "H@Sh1CoR3!"
  }
  set {
    name = "externalDatabase.port"
    value =  5432
  }
  set {
    name = "externalRedis.host"
    value = azurerm_redis_cache.example.hostname
  }
  set {
    name = "externalRedis.port"
    value = azurerm_redis_cache.example.port
  }
  set {
    name = "externalRedis.password"
    value = azurerm_redis_cache.example.primary_access_key
  }

   set {
    name = "auth.password"
    value = "password"
  }
  set {
    name = "auth.username"
    value = "admin"
  }
  set {
    name = "auth.fernetKey"
    value = "kHDkzuRlXIEdyTwOXiOuGlSokCfoLupuykHTDI2IOco="
  }

}

provider "kubernetes" {
  alias = "existing"
  host = azurerm_kubernetes_cluster.example.kube_config.0.host
  client_certificate = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_certificate)
  client_key = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.cluster_ca_certificate)
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

resource "kubernetes_config_map" "dags" {
  provider = kubernetes.existing
  metadata {
    name = "dags"
  }

  data = {

    "databricks.py" = file("databricks.py")
    "databricks1.py" = file("databricks1.py")
  }
}