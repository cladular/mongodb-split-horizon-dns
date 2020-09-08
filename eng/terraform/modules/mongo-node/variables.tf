variable "deployment_name" {
  type        = string
  description = "Deployment name."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name."
}

variable "location" {
  type        = string
  description = "Private network location."
}

variable "nodes_count" {
  type        = number
  description = "Number of MongoDB nodes."
}

variable "zone_name" {
  type        = string
  description = "DNS zone name."
}

variable "network_profile_id" {
  type        = string
  description = "Network profile ID."
}

variable "storage_account_name" {
  type        = string
  description = "Storage account name."
}

variable "storage_primary_key" {
  type        = string
  description = "Storage primary key."
}

variable "replica_set" {
  type        = string
  description = "MongoDB replica set."
}

variable "nodes_list" {
  type        = map(string)
  description = "MongoDB nodes list."
}
