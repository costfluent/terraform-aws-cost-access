variable "costfluent_principal_arn" {
  description = "The Costfluent role to trust, from data.costfluent_aws_provider_info.principal_arn."
  type        = string
}

variable "external_id" {
  description = "Your Costfluent organization's external ID, from data.costfluent_aws_provider_info.external_id."
  type        = string
  sensitive   = true
}

variable "cost_export_bucket_name" {
  description = "The bucket you already have, in this account."
  type        = string
}

variable "cost_export_bucket_region" {
  description = "The region of that bucket."
  type        = string
}

variable "export_prefix" {
  description = "The prefix the exports are delivered under in that bucket."
  type        = string
  default     = "costfluent"
}

variable "cost_export_exists" {
  description = "true to read a FOCUS 1.2 export the bucket already receives instead of creating one."
  type        = bool
  default     = false
}

variable "export_name" {
  description = "The FOCUS 1.2 export to create, or the one the bucket already receives."
  type        = string
  default     = "costfluent-focus"
}
