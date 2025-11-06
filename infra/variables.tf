variable "resource_group_name_prefix" {
  description = "Prefix for resource group names"
  type        = string
  default     = "rg"   # Set a sensible default or leave empty
}

variable "resource_group_name" {
  default = "rg-weather"
}

variable "location" {
  default = "westeurope"
}

variable "acr_name" {
  default = "weatheracr2025"
}

variable "aks_name" {
  default = "aks-cluster-weather"
}

variable "tenant_id" {
  type = string
  description = "Tenant ID for Azure"
}

variable "object_id" {
  type = string
  description = "Object ID for Azure Principal"
}

variable "max_node" {
  type = int
  default = 5
  description = "max number of node"
}