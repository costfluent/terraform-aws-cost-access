# Grants Costfluent read-only access to one AWS account's cost data, and in a management account
# creates the FOCUS 1.2 and carbon emissions Data Exports Costfluent reads.
#
# Costfluent assumes this role from its connector role, proving intent with the external ID that
# Costfluent issues to your organization (the costfluent_aws_provider_info data source). The role
# can read Cost Explorer, list the organization's accounts, and read the export bucket; nothing
# else. Every action granted here is one the Costfluent backend calls, and Costfluent's own build
# fails when the two differ.

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  account_id    = data.aws_caller_identity.current.account_id
  partition     = data.aws_partition.current.partition
  create_export = var.cost_export_bucket_name != ""
  bucket_arn    = "arn:${local.partition}:s3:::${var.cost_export_bucket_name}"

  # A bucket or FOCUS export the customer already has is read, never created or changed.
  create_bucket       = local.create_export && !var.cost_export_bucket_exists
  create_focus_export = local.create_export && !var.cost_export_exists

  # The FOCUS 1.2 with AWS columns table, every column, as the Data Exports column dictionary lists
  # it (table-dictionary-focus-1-2-aws-columns). The CloudFormation template selects the same list.
  focus_columns = [
    "AvailabilityZone", "BilledCost", "BillingAccountId", "BillingAccountName", "BillingAccountType",
    "BillingCurrency", "BillingPeriodEnd", "BillingPeriodStart", "CapacityReservationId",
    "CapacityReservationStatus", "ChargeCategory", "ChargeClass", "ChargeDescription", "ChargeFrequency",
    "ChargePeriodEnd", "ChargePeriodStart", "CommitmentDiscountCategory", "CommitmentDiscountId",
    "CommitmentDiscountName", "CommitmentDiscountQuantity", "CommitmentDiscountStatus",
    "CommitmentDiscountType", "CommitmentDiscountUnit", "ConsumedQuantity", "ConsumedUnit",
    "ContractedCost", "ContractedUnitPrice", "EffectiveCost", "InvoiceId", "InvoiceIssuerName",
    "ListCost", "ListUnitPrice", "PricingCategory", "PricingCurrency", "PricingCurrencyContractedUnitPrice",
    "PricingCurrencyEffectiveCost", "PricingCurrencyListUnitPrice", "PricingQuantity", "PricingUnit",
    "ProviderName", "PublisherName", "RegionId", "RegionName", "ResourceId", "ResourceName", "ResourceType",
    "ServiceCategory", "ServiceName", "ServiceSubcategory", "SkuId", "SkuMeter", "SkuPriceDetails",
    "SkuPriceId", "SubAccountId", "SubAccountName", "SubAccountType", "Tags", "x_Discounts", "x_Operation",
    "x_ServiceCode",
  ]

  # The carbon export rides on the FOCUS export's bucket and prefix, which the role already reads,
  # so it needs no grant of its own.
  create_carbon_export = local.create_export && var.carbon_export_name != ""

  # The CARBON_EMISSIONS table, every column, as the Data Exports column dictionary lists it
  # (carbon-emissions-columns). The CloudFormation template selects the same list.
  carbon_columns = [
    "last_refresh_timestamp", "usage_period_start", "usage_period_end", "location", "model_version",
    "payer_account_id", "usage_account_id", "product_code", "region_code",
    "total_lbm_emissions_value", "total_lbm_emissions_unit",
    "total_mbm_emissions_value", "total_mbm_emissions_unit",
    "total_scope_1_emissions_value", "total_scope_1_emissions_unit",
    "total_scope_2_lbm_emissions_value", "total_scope_2_lbm_emissions_unit",
    "total_scope_2_mbm_emissions_value", "total_scope_2_mbm_emissions_unit",
    "total_scope_3_lbm_emissions_value", "total_scope_3_lbm_emissions_unit",
    "total_scope_3_mbm_emissions_value", "total_scope_3_mbm_emissions_unit",
  ]
}

resource "aws_iam_role" "costfluent" {
  name        = var.role_name
  description = "Read-only cost access for Costfluent."

  assume_role_policy = jsonencode({
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
  })

  # Costfluent reaches this role by chaining from its connector role, and AWS caps a chained session
  # at one hour whatever this says.
  max_session_duration = 3600
  tags                 = var.tags
}

resource "aws_iam_role_policy" "costfluent_cost_read" {
  name = "CostfluentCostRead"
  role = aws_iam_role.costfluent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CostExplorerReadOnly"
        Effect = "Allow"
        # History before the export's first delivery, accounts with no export, and the monthly
        # control total. Cost Explorer has no resource-level permissions, so "*" is the only
        # resource the API accepts; it grants no access to anything in the account.
        Action   = ["ce:GetCostAndUsage"]
        Resource = "*"
      },
      {
        Sid    = "CostExplorerCommitmentsReadOnly"
        Effect = "Allow"
        # The Reserved Instances and Savings Plans the account holds, with their utilisation and
        # end dates, read once a day into Commitments. Cost Explorer has no resource-level
        # permissions, so "*" is the only resource it accepts.
        Action = [
          "ce:GetReservationUtilization",
          "ce:GetSavingsPlansUtilizationDetails",
        ]
        Resource = "*"
      },
      {
        Sid    = "OrganizationsReadOnly"
        Effect = "Allow"
        # Which member accounts a management account's cost covers. Denied or unused outside an
        # organization, which Costfluent treats as one account.
        Action   = ["organizations:ListAccounts"]
        Resource = "*"
      },
      {
        Sid    = "CostOptimizationHubReadOnly"
        Effect = "Allow"
        # The rightsizing, idle, upgrade and commitment purchase recommendations Cost Optimization
        # Hub already computes, read once a day into the savings queue, and whether the account
        # is enrolled, so a hub that is not turned on reads as a step to take, not a refusal. The
        # API has no resource-level permissions, so "*" is the only resource it accepts.
        Action = [
          "cost-optimization-hub:ListRecommendations",
          "cost-optimization-hub:ListEnrollmentStatuses",
        ]
        Resource = "*"
      },
      {
        Sid    = "CreditsReadOnly"
        Effect = "Allow"
        # The credits AWS has granted the account, or a management account's organization, with
        # their remaining amounts and expiry, read once a day into the connection's Credits card.
        # The action has no resource type, so "*" is the only resource it accepts.
        Action   = ["billing:GetCredits"]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy" "costfluent_export_read" {
  count = local.create_export ? 1 : 0

  name = "CostfluentExportRead"
  role = aws_iam_role.costfluent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Listing stays on the whole bucket with no prefix condition: S3 answers a read of a missing
      # key with 404 only to a role that may list the bucket, and Costfluent reads a month's missing
      # manifest as "not delivered yet" from that 404 rather than failing on a 403. A list shows key
      # names, not contents.
      {
        Sid      = "ExportBucketList"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = local.bucket_arn
      },
      {
        Sid      = "ExportObjectRead"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${local.bucket_arn}/${var.export_prefix}/*"
      },
    ]
  })
}

resource "aws_s3_bucket" "export" {
  count = local.create_bucket ? 1 : 0

  region = var.cost_export_bucket_region
  bucket = var.cost_export_bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_public_access_block" "export" {
  count = local.create_bucket ? 1 : 0

  region                  = var.cost_export_bucket_region
  bucket                  = aws_s3_bucket.export[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "export" {
  count = local.create_bucket ? 1 : 0

  region = var.cost_export_bucket_region
  bucket = aws_s3_bucket.export[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# No lifecycle expiry: a backfill re-reads past months, and an expired delivery is history lost.
resource "aws_s3_bucket_policy" "export" {
  count = local.create_bucket ? 1 : 0

  region = var.cost_export_bucket_region
  bucket = aws_s3_bucket.export[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowDataExportsDelivery"
        Effect    = "Allow"
        Principal = { Service = ["billingreports.amazonaws.com", "bcm-data-exports.amazonaws.com"] }
        Action    = ["s3:PutObject", "s3:GetBucketPolicy"]
        Resource  = [local.bucket_arn, "${local.bucket_arn}/*"]
        Condition = {
          StringEquals = { "aws:SourceAccount" = local.account_id }
          StringLike = {
            "aws:SourceArn" = [
              "arn:${local.partition}:cur:us-east-1:${local.account_id}:definition/*",
              "arn:${local.partition}:bcm-data-exports:us-east-1:${local.account_id}:export/*",
            ]
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [local.bucket_arn, "${local.bucket_arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.export]
}

resource "aws_bcmdataexports_export" "focus" {
  count = local.create_focus_export ? 1 : 0

  export {
    name        = var.export_name
    description = "FOCUS 1.2 cost and usage for Costfluent."

    data_query {
      query_statement = "SELECT ${join(", ", local.focus_columns)} FROM FOCUS_1_2_AWS"
      table_configurations = {
        FOCUS_1_2_AWS = {
          TIME_GRANULARITY = "DAILY"
        }
      }
    }

    destination_configurations {
      s3_destination {
        s3_bucket = var.cost_export_bucket_name
        s3_prefix = var.export_prefix
        s3_region = var.cost_export_bucket_region

        s3_output_configurations {
          overwrite   = "OVERWRITE_REPORT"
          format      = "TEXT_OR_CSV"
          compression = "GZIP"
          output_type = "CUSTOM"
        }
      }
    }

    refresh_cadence {
      frequency = "SYNCHRONOUS"
    }
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = data.aws_region.current.region == "us-east-1"
      error_message = "AWS Data Exports runs in us-east-1: configure this module's aws provider with region = \"us-east-1\". The export bucket may be elsewhere through cost_export_bucket_region."
    }
  }

  depends_on = [aws_s3_bucket_policy.export]
}

# The provider-reported carbon footprint of the same accounts, monthly, in the bucket and under the
# prefix the FOCUS export uses. CARBON_EMISSIONS has no table configurations. Whoever applies this
# needs sustainability:GetCarbonFootprintSummary; set carbon_export_name = "" to skip it.
resource "aws_bcmdataexports_export" "carbon" {
  count = local.create_carbon_export ? 1 : 0

  export {
    name        = var.carbon_export_name
    description = "Carbon emissions for Costfluent."

    data_query {
      query_statement = "SELECT ${join(", ", local.carbon_columns)} FROM CARBON_EMISSIONS"
    }

    destination_configurations {
      s3_destination {
        s3_bucket = var.cost_export_bucket_name
        s3_prefix = var.export_prefix
        s3_region = var.cost_export_bucket_region

        s3_output_configurations {
          overwrite   = "OVERWRITE_REPORT"
          format      = "PARQUET"
          compression = "PARQUET"
          output_type = "CUSTOM"
        }
      }
    }

    refresh_cadence {
      frequency = "SYNCHRONOUS"
    }
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = data.aws_region.current.region == "us-east-1"
      error_message = "AWS Data Exports runs in us-east-1: configure this module's aws provider with region = \"us-east-1\". The export bucket may be elsewhere through cost_export_bucket_region."
    }

    precondition {
      condition     = var.carbon_export_name != var.export_name
      error_message = "carbon_export_name must differ from export_name: both exports live in one account, where an export name is unique."
    }
  }

  depends_on = [aws_s3_bucket_policy.export]
}
