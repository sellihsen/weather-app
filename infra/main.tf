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

resource "azapi_resource" "limit_node_count_policy_definition" {
  type = "Microsoft.Authorization/policyDefinitions@2021-06-01"
  name = "limit-node-count"
  parent_id = var.subscription_id
  body = jsonencode({
    properties = {
      displayName = "Limit node count to 5 in AKS"
      policyType  = "Custom"
      mode        = "All"
      description = "This policy restricts the node count to maximum 5 for AKS clusters"
      policyRule  = {
        if = {
          allOf = [
            {
              field = "type"
              equals = "Microsoft.ContainerService/ManagedClusters"
            },
            {
              field = "Microsoft.ContainerService/ManagedClusters/agentPoolProfiles[*].count"
              greaterThan = 5
            }
          ]
        }
        then = {
          effect = "deny"
        }
      }
    }
  })
}

resource "azapi_resource" "limit_node_count_assignment" {
  type = "Microsoft.Authorization/policyAssignments@2020-09-01"
  name = "limit-node-count-assignment"
  parent_id = azurerm_resource_group.rg.id

  body = jsonencode({
    properties = {
      displayName       = "Limit node count to 5"
      policyDefinitionId = azapi_resource.limit_node_count_policy_definition.id
      enforcementMode    = "Default"
      scope              = azurerm_resource_group.rg.id
    }
  })
}

resource "azapi_resource" "restrict_region_policy_definition" {
  type      = "Microsoft.Authorization/policyDefinitions@2021-06-01"
  name      = "restrict-region"
  parent_id = var.subscription_id

  body = jsonencode({
    properties = {
      displayName = "Restrict AKS deployment to Westeurope"
      policyType  = "Custom"
      mode        = "All"
      description = "This policy enforces deployment only in Westeurope"
      policyRule  = {
        if = {
          field = "location"
          notEquals = "westeurope"
        }
        then = {
          effect = "deny"
        }
      }
    }
  })
}

resource "azapi_resource" "restrict_region_assignment" {
  type      = "Microsoft.Authorization/policyAssignments@2020-09-01"
  name      = "restrict-region-assignment"
  parent_id = azurerm_resource_group.rg.id

  body = jsonencode({
    properties = {
      displayName       = "Restrict AKS to Westeurope"
      policyDefinitionId = azapi_resource.restrict_region_policy_definition.id
      enforcementMode    = "Default"
      scope              = azurerm_resource_group.rg.id
    }
  })
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  version    = "v1.19.1"

  set = [
    {
      name  = "installCRDs"
      value = "true"
    }
  ]
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
