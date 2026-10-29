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
  costfluent_principal_arn = "arn:aws:iam::123456789012:role/costfluent-connector"
  external_id              = "cf-0123456789abcdef0123456789abcdef"
  cost_export_bucket_name  = "acme-export"
}

run "the_role_carries_only_its_inline_policies" {
  command = apply

  assert {
    condition = sort(flatten([
      for policy in concat([aws_iam_role_policy.costfluent_cost_read], aws_iam_role_policy.costfluent_export_read) : [
        for statement in jsondecode(policy.policy).Statement : statement.Sid
      ]
      ])) == sort([
      "CostExplorerReadOnly",
      "CostExplorerCommitmentsReadOnly",
      "OrganizationsReadOnly",
      "CostOptimizationHubReadOnly",
      "CreditsReadOnly",
      "ExportBucketList",
      "ExportObjectRead",
    ])
    error_message = "The role's inline policies must hold exactly these statements: a new one widens every customer's grant, so it is named here deliberately, beside the backend call that needs it."
  }

  assert {
    condition     = length(aws_iam_role.costfluent.managed_policy_arns) == 0
    error_message = "The role must carry no managed policy: every action it holds is granted by its inline policies, which Costfluent's build checks against what the backend calls."
  }
}
