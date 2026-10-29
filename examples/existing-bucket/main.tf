# A management (or standalone) account with an S3 bucket it already has: the role, and the FOCUS 1.2
# and carbon emissions exports delivered into that bucket under export_prefix. The module creates no
# bucket and writes no bucket policy, so for a new export the bucket's policy must already allow AWS
# Data Exports to deliver (see the module README). Set cost_export_exists = true to read a FOCUS 1.2
# export the bucket already receives, named in export_name, instead of creating one.
module "costfluent" {
  source = "../.."

  costfluent_principal_arn  = var.costfluent_principal_arn
  external_id               = var.external_id
  cost_export_bucket_name   = var.cost_export_bucket_name
  cost_export_bucket_exists = true
  cost_export_bucket_region = var.cost_export_bucket_region
  export_prefix             = var.export_prefix
  cost_export_exists        = var.cost_export_exists
  export_name               = var.export_name
}

output "credentials" {
  value = module.costfluent.credentials
}

output "settings" {
  value = module.costfluent.settings
}
