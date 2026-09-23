variable "costfluent_principal_arn" {
  description = "The Costfluent role your role trusts. Read it from data.costfluent_aws_provider_info.principal_arn."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:role/.+$", var.costfluent_principal_arn))
    error_message = "Must be an IAM role ARN."
  }
}

variable "external_id" {
  description = "Your Costfluent organization's external ID. Read it from data.costfluent_aws_provider_info.external_id; do not invent one."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^cf-[0-9a-f]{32}$", var.external_id))
    error_message = "Must be the external ID Costfluent issued: cf- followed by 32 hex characters."
  }
}

variable "cost_export_bucket_name" {
  description = "Bucket to create for the FOCUS 1.2 Data Export, in a management or standalone account. Leave empty in a member account: its cost arrives through the management account's export."
  type        = string
  default     = ""

  validation {
    condition     = var.cost_export_bucket_name == "" || can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.cost_export_bucket_name))
    error_message = "Must be empty or a valid S3 bucket name."
  }
}

variable "cost_export_bucket_region" {
  description = "Region of the export bucket. The export itself always runs in us-east-1; an EU region keeps the delivered files in the EU."
  type        = string
  default     = "us-east-1"
}

variable "export_name" {
  description = "Name of the Data Export."
  type        = string
  default     = "costfluent-focus"

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{1,128}$", var.export_name))
    error_message = "May hold only letters, digits, '-' and '_'."
  }
}

variable "role_name" {
  description = "Name of the IAM role Costfluent assumes."
  type        = string
  default     = "CostfluentBillingRole"

  validation {
    condition     = can(regex("^[a-zA-Z0-9+=,.@_-]{1,64}$", var.role_name))
    error_message = "Must be a valid IAM role name (up to 64 characters)."
  }
}

variable "tags" {
  description = "Tags applied to every resource the module creates."
  type        = map(string)
  default     = {}
}
