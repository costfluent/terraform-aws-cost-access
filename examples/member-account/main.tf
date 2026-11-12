# A member account of an AWS Organization whose management account you do not connect to Costfluent:
# only the role, with no bucket and no export, and Costfluent reads the account's cost from Cost
# Explorer. A member of a management account you do connect is covered by that connection, and
# Costfluent refuses a second one for it.
module "costfluent" {
  source = "../.."

  costfluent_principal_arn = var.costfluent_principal_arn
  external_id              = var.external_id
}

output "credentials" {
  value = module.costfluent.credentials
}
