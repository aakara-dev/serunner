variable "name_prefix" {
  description = "Short prefix used in resource names, e.g. \"glrun\"."
  type        = string
}

variable "location" {
  description = "Azure region for all network resources."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that holds the VNet and NSGs."
  type        = string
}

variable "address_space" {
  description = "VNet CIDR."
  type        = string
  default     = "10.60.0.0/16"
}

variable "manager_subnet_prefix" {
  description = "CIDR for the runner manager subnet."
  type        = string
  default     = "10.60.1.0/24"
}

variable "workers_subnet_prefix" {
  description = "CIDR for the autoscaled worker subnet (Linux and Windows VMSS)."
  type        = string
  default     = "10.60.2.0/23"
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
