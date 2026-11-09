variable "name_prefix" {
  description = "Short prefix used in resource names, e.g. \"glrun\"."
  type        = string
}

variable "location" {
  description = "Azure region for the NSG."
  type        = string
}

variable "resource_group_name" {
  description = "Workload resource group that holds the NSG."
  type        = string
}

variable "vnet_resource_group_name" {
  description = "Resource group of the existing spoke VNet (the subnet is created there)."
  type        = string
}

variable "vnet_name" {
  description = "Name of the existing spoke VNet."
  type        = string
}

variable "subnet_prefix" {
  description = "Free CIDR inside the spoke VNet for the runner subnet. /27 recommended, /28 minimum."
  type        = string

  validation {
    condition     = can(cidrhost(var.subnet_prefix, 0)) && tonumber(split("/", var.subnet_prefix)[1]) <= 28
    error_message = "subnet_prefix must be a valid CIDR of /28 or larger."
  }
}

variable "route_table_id" {
  description = "Spoke route table that sends 0.0.0.0/0 to the hub firewall. Null if policy attaches it for you."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
