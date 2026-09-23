# A member account of an AWS Organization: only the role. Its cost arrives through the management
# account's export, so it gets no bucket and no export, and Costfluent reads Cost Explorer for it.
module "costfluent" {
  source = "../.."

  costfluent_principal_arn = var.costfluent_principal_arn
  external_id              = var.external_id
}

output "credentials" {
  value = module.costfluent.credentials
}
