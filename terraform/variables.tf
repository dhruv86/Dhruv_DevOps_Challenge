# Variables
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-dhruv86-webapp"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "app_name_prefix" {
  description = "Prefix for the app service name"
  type        = string
  default     = "hello-world"
}