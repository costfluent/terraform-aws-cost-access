# The credential field names are the contract Costfluent validates against
# (ProviderDefinitions.Aws.RequiredCredentialFields in the Costfluent backend). Renaming one here
# breaks every connection made with this module; scripts/check-integration-contract.py asserts it.
locals {
  credentials = {
    role_arn    = aws_iam_role.costfluent.arn
    external_id = var.external_id
  }
}

output "credentials" {
  description = "Credential fields for the Costfluent AWS connection."
  sensitive   = true
  value       = local.credentials
}

output "credentials_json" {
  description = "The same credentials as a JSON object, ready to paste into Costfluent."
  sensitive   = true
  value       = jsonencode(local.credentials)
}

output "role_arn" {
  description = "ARN of the role Costfluent assumes."
  value       = aws_iam_role.costfluent.arn
}

output "account_id" {
  description = "Account the role was created in, to confirm you targeted the right one."
  value       = data.aws_caller_identity.current.account_id
}
