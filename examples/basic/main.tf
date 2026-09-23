# A management (or standalone) account: the role, the export bucket and the FOCUS 1.2 export.
# In your own configuration, read both Costfluent values from the costfluent_aws_provider_info
# data source instead of variables (see the module README).
module "costfluent" {
  source = "../.."

  costfluent_principal_arn = var.costfluent_principal_arn
  external_id              = var.external_id
  cost_export_bucket_name  = var.cost_export_bucket_name
}

output "credentials" {
  value = module.costfluent.credentials
}

output "settings" {
  value = module.costfluent.settings
}
