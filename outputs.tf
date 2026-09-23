# The field names are the contract Costfluent validates against: credentials against
# ProviderDefinitions.Aws.RequiredCredentialFields, settings against its OptionalSettingFields.
# Renaming one here breaks every connection made with this module; scripts/check-integration-contract.py
# asserts both. Neither authenticates: access comes from the role's trust in Costfluent's principal
# and your organization's external ID, which Costfluent adds itself.
locals {
  credentials = {
    role_arn = aws_iam_role.costfluent.arn
  }

  settings = local.create_export ? {
    export_bucket        = var.cost_export_bucket_name
    export_bucket_region = var.cost_export_bucket_region
    export_prefix        = "costfluent"
    export_name          = var.export_name
  } : {}
}

output "credentials" {
  description = "Credential fields for costfluent_provider."
  value       = local.credentials
}

output "credentials_json" {
  description = "The same credentials as a JSON object, for the Costfluent console."
  value       = jsonencode(local.credentials)
}

output "settings" {
  description = "Settings for costfluent_provider: where the FOCUS export lands. Empty in a member account."
  value       = local.settings
}

output "role_arn" {
  description = "ARN of the role Costfluent assumes."
  value       = aws_iam_role.costfluent.arn
}

output "account_id" {
  description = "Account the role was created in, to confirm you targeted the right one."
  value       = data.aws_caller_identity.current.account_id
}
