variable "costfluent_principal_arn" {
  description = "The Costfluent role to trust, from data.costfluent_aws_provider_info.principal_arn."
  type        = string
}

variable "external_id" {
  description = "Your Costfluent organization's external ID, from data.costfluent_aws_provider_info.external_id."
  type        = string
  sensitive   = true
}
