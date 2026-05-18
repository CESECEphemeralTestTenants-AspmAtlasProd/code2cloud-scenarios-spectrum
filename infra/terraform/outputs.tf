output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "acr_name" {
  value = azurerm_container_registry.lab.name
}

output "acr_login_server" {
  value = azurerm_container_registry.lab.login_server
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.lab.name
}

output "k8s_namespace" {
  value = "c2c-scenarios"
}

output "resource_prefix" {
  value = var.resource_prefix
}