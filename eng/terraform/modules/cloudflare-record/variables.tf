variable "deployment_name" {
  type        = string
  description = "Deployment name."
}

variable "zone_name" {
  type        = string
  description = "Zone name."
}

variable "pips" {
  type        = list(string)
  description = "Public IPs."
}
