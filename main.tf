# Grants Costfluent read-only access to one AWS account's cost data.
#
# Costfluent assumes this role from its own account, proving intent with the external ID the
# Costfluent UI generates for the connection. The role can read Cost Explorer and nothing else.

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

resource "aws_iam_role" "costfluent" {
  name        = var.role_name
  description = "Read-only AWS Cost Explorer access for Costfluent."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "CostfluentAssumeRole"
      Effect    = "Allow"
      Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${var.costfluent_account_id}:root" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "sts:ExternalId" = var.external_id }
      }
    }]
  })

  max_session_duration = var.max_session_duration
  tags                 = var.tags
}

resource "aws_iam_role_policy" "costfluent_billing" {
  name = "CostfluentBillingAccess"
  role = aws_iam_role.costfluent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "CostExplorerReadOnly"
      Effect = "Allow"
      # Cost Explorer has no resource-level permissions; "*" is the only valid resource.
      Action = [
        "ce:GetCostAndUsage",
        "ce:GetCostForecast",
        "ce:GetDimensionValues",
        "ce:GetTags",
        "ce:GetReservationUtilization",
        "ce:GetSavingsPlansUtilization",
      ]
      Resource = "*"
    }]
  })
}
