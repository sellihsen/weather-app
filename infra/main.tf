resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
  # public_network_access_enabled = false
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.resource_group_name}-law"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = var.aks_name

  default_node_pool {
    name       = "agentpool"
    node_count = 3
    vm_size    = "Standard_B2s"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "calico"
  }

  sku_tier = "Free"
  
  depends_on = [azurerm_container_registry.acr]
}

resource "azurerm_policy_definition" "limit_node_count" {
  name         = "limit-node-count"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Limit node count to 5 in AKS"
  description  = "This policy restricts the node count to maximum 5 for AKS clusters"

  policy_rule = <<POLICY
  {
    "if": {
      "allOf": [
        {
          "field": "type",
          "equals": "Microsoft.ContainerService/ManagedClusters"
        },
        {
          "field": "Microsoft.ContainerService/ManagedClusters/agentPoolProfiles[*].count",
          "greaterThan": var.max_node
        }
      ]
    },
    "then": {
      "effect": "deny"
    }
  }
  POLICY
}

resource "azurerm_policy_assignment" "limit_node_count" {
  name                 = "limit-node-count"
  scope                = azurerm_resource_group.rg.id
  policy_definition_id = azurerm_policy_definition.limit_node_count.id
}

resource "azurerm_policy_definition" "restrict_region" {
  name = "restrict-region"
  policy_type = "Custom"
  mode = "All"
  display_name = "Restrict AKS deployment to Westeurope"
  description = "This policy enforces deployment only in Westeurope"

  policy_rule = <<POLICY
  {
    "if": {
      "field": "location",
      "notEquals": "westeurope"
    },
    "then": {
      "effect": "deny"
    }
  }
  POLICY
}

resource "azurerm_policy_assignment" "restrict_region" {
  name = "restrict-region"
  scope = azurerm_resource_group.rg.id
  policy_definition_id = azurerm_policy_definition.restrict_region.id
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  version    = "v1.19.1"

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "kubernetes_namespace" "weather_production" {
  metadata {
    name = "ns-weather-production"
  }
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

resource "azurerm_application_insights" "appi" {
  name                = "${var.aks_name}-appi"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
}

resource "azurerm_key_vault" "kv" {
  name                        = "${var.resource_group_name}-kv"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = var.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = false
  soft_delete_retention_days  = 7
  
  access_policy {
    tenant_id = var.tenant_id
    object_id = var.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete"
    ]
  }
}
