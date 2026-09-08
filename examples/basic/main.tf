module "costfluent" {
  source = "../.."

  costfluent_account_id = var.costfluent_account_id
  external_id           = var.external_id
}

output "credentials_json" {
  value     = module.costfluent.credentials_json
  sensitive = true
}
