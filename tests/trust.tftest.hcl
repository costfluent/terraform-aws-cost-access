mock_provider "aws" {
  override_data {
    target = data.aws_partition.current
    values = {
      partition = "aws"
    }
  }

  override_data {
    target = data.aws_region.current
    values = {
      region = "us-east-1"
    }
  }
}

variables {
  costfluent_principal_arn  = "arn:aws:iam::123456789012:role/costfluent-connector"
  external_id               = "cf-0123456789abcdef0123456789abcdef"
  cost_export_bucket_name   = "acme-finops"
  cost_export_bucket_exists = true
  cost_export_bucket_region = "eu-central-1"
  export_prefix             = "finops/costfluent"
}

run "the_role_trusts_only_the_connector_with_the_external_id" {
  command = apply

  assert {
    condition = jsondecode(aws_iam_role.costfluent.assume_role_policy) == {
      Version = "2012-10-17"
      Statement = [{
        Sid       = "CostfluentAssumeRole"
        Effect    = "Allow"
        Principal = { AWS = var.costfluent_principal_arn }
        Action    = "sts:AssumeRole"
        Condition = {
          StringEquals = { "sts:ExternalId" = var.external_id }
        }
      }]
    }
    error_message = "The role must trust only Costfluent's connector role, only for sts:AssumeRole, and only with StringEquals on the organization's external ID: anything wider lets the connector assume it for another organization, or lets someone outside Costfluent assume it."
  }
}
