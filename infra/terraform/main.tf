locals {
  tags = {
    purpose     = "c2c-testing"
    environment = var.environment
    repository  = var.github_repo
  }
}

resource "azurerm_resource_group" "lab" {
  name     = "${var.resource_prefix}-rg"
  location = var.location
  tags     = local.tags
}

resource "azurerm_container_registry" "lab" {
  name                          = "${var.resource_prefix}acr"
  resource_group_name           = azurerm_resource_group.lab.name
  location                      = azurerm_resource_group.lab.location
  sku                           = "Basic"
  admin_enabled                 = false
  anonymous_pull_enabled        = false
  public_network_access_enabled = true
  tags                          = local.tags
}

resource "azurerm_kubernetes_cluster" "lab" {
  name                = "${var.resource_prefix}-aks"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  dns_prefix          = "${var.resource_prefix}-aks"
  tags                = local.tags

  default_node_pool {
    name       = "system"
    node_count = var.aks_node_count
    vm_size    = var.aks_node_size
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.lab.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.lab.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "workflow_acr_push" {
  count                            = var.workflow_principal_object_id == "" ? 0 : 1
  principal_id                     = var.workflow_principal_object_id
  role_definition_name             = "AcrPush"
  scope                            = azurerm_container_registry.lab.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "workflow_aks_cluster_user" {
  count                            = var.workflow_principal_object_id == "" ? 0 : 1
  principal_id                     = var.workflow_principal_object_id
  role_definition_name             = "Azure Kubernetes Service Cluster User Role"
  scope                            = azurerm_kubernetes_cluster.lab.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "workflow_aks_rbac_writer" {
  count                            = var.workflow_principal_object_id == "" ? 0 : 1
  principal_id                     = var.workflow_principal_object_id
  role_definition_name             = "Azure Kubernetes Service RBAC Writer"
  scope                            = azurerm_kubernetes_cluster.lab.id
  skip_service_principal_aad_check = true
}

resource "azurerm_security_center_subscription_pricing" "containers" {
  count         = var.enable_defender_plans ? 1 : 0
  tier          = "Standard"
  resource_type = "Containers"
}

resource "azurerm_security_center_subscription_pricing" "cloud_posture" {
  count         = var.enable_defender_plans ? 1 : 0
  tier          = "Standard"
  resource_type = "CloudPosture"
}