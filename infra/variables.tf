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
