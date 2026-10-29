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

run "an_existing_bucket_gets_the_exports_and_nothing_else" {
  command = apply

  assert {
    condition = alltrue([
      length(aws_s3_bucket.export) == 0,
      length(aws_s3_bucket_public_access_block.export) == 0,
      length(aws_s3_bucket_server_side_encryption_configuration.export) == 0,
      length(aws_s3_bucket_policy.export) == 0,
    ])
    error_message = "A bucket the customer already has must get no bucket, public access block, encryption or bucket policy from the module."
  }

  assert {
    condition = alltrue([
      for export in [aws_bcmdataexports_export.focus[0], aws_bcmdataexports_export.carbon[0]] :
      export.export[0].destination_configurations[0].s3_destination[0].s3_bucket == "acme-finops" &&
      export.export[0].destination_configurations[0].s3_destination[0].s3_region == "eu-central-1" &&
      export.export[0].destination_configurations[0].s3_destination[0].s3_prefix == "finops/costfluent"
    ])
    error_message = "The FOCUS and carbon exports must write to the named bucket, in its region, under the given prefix."
  }

  assert {
    condition = {
      for statement in jsondecode(aws_iam_role_policy.costfluent_export_read[0].policy).Statement :
      statement.Sid => statement.Resource
      } == {
      ExportBucketList = "arn:aws:s3:::acme-finops"
      ExportObjectRead = "arn:aws:s3:::acme-finops/finops/costfluent/*"
    }
    error_message = "The role must list the named bucket and read objects only under the given prefix."
  }

  assert {
    condition = output.settings == {
      export_bucket        = "acme-finops"
      export_bucket_region = "eu-central-1"
      export_prefix        = "finops/costfluent"
      export_name          = "costfluent-focus"
      carbon_export_name   = "costfluent-carbon"
    }
    error_message = "The settings must carry the named bucket, its region and the prefix, where Costfluent reads."
  }
}

run "an_existing_export_is_read_and_not_created" {
  command = apply

  variables {
    cost_export_exists = true
    export_name        = "acme-focus-daily"
  }

  assert {
    condition     = length(aws_bcmdataexports_export.focus) == 0
    error_message = "An export the customer already has must not be created again."
  }

  assert {
    condition = alltrue([
      length(aws_bcmdataexports_export.carbon) == 1,
      aws_bcmdataexports_export.carbon[0].export[0].destination_configurations[0].s3_destination[0].s3_prefix == "finops/costfluent",
      length(aws_iam_role_policy.costfluent_export_read) == 1,
    ])
    error_message = "The carbon export and the read grant must still be created beside an existing FOCUS export."
  }

  assert {
    condition     = output.settings.export_name == "acme-focus-daily" && output.settings.export_prefix == "finops/costfluent"
    error_message = "The settings must carry the existing export's name and prefix, where Costfluent reads it."
  }
}

run "a_bucket_the_module_creates_keeps_its_policy_and_prefix" {
  command = apply

  variables {
    cost_export_bucket_exists = false
  }

  override_data {
    target = data.aws_caller_identity.current
    values = {
      account_id = "111122223333"
    }
  }

  assert {
    condition = alltrue([
      length(aws_s3_bucket.export) == 1,
      length(aws_s3_bucket_public_access_block.export) == 1,
      length(aws_s3_bucket_server_side_encryption_configuration.export) == 1,
      length(aws_s3_bucket_policy.export) == 1,
      length(aws_bcmdataexports_export.focus) == 1,
    ])
    error_message = "Without cost_export_bucket_exists the module must still create the bucket, its protections, its policy and the FOCUS export."
  }

  assert {
    condition     = aws_bcmdataexports_export.focus[0].export[0].destination_configurations[0].s3_destination[0].s3_prefix == "finops/costfluent" && output.settings.export_prefix == "finops/costfluent"
    error_message = "A bucket the module creates must take the given prefix too."
  }

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.export[0].block_public_acls,
      aws_s3_bucket_public_access_block.export[0].block_public_policy,
      aws_s3_bucket_public_access_block.export[0].ignore_public_acls,
      aws_s3_bucket_public_access_block.export[0].restrict_public_buckets,
    ])
    error_message = "A bucket the module creates must block public ACLs and public policies, ignore public ACLs and restrict public buckets: it holds the customer's whole cost and usage history."
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.export[0].rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
    error_message = "A bucket the module creates must encrypt every object with SSE-S3 (AES256)."
  }

  assert {
    condition = jsondecode(aws_s3_bucket_policy.export[0].policy) == {
      Version = "2012-10-17"
      Statement = [
        {
          Sid       = "AllowDataExportsDelivery"
          Effect    = "Allow"
          Principal = { Service = ["billingreports.amazonaws.com", "bcm-data-exports.amazonaws.com"] }
          Action    = ["s3:PutObject", "s3:GetBucketPolicy"]
          Resource  = ["arn:aws:s3:::acme-finops", "arn:aws:s3:::acme-finops/*"]
          Condition = {
            StringEquals = { "aws:SourceAccount" = "111122223333" }
            StringLike = {
              "aws:SourceArn" = [
                "arn:aws:cur:us-east-1:111122223333:definition/*",
                "arn:aws:bcm-data-exports:us-east-1:111122223333:export/*",
              ]
            }
          }
        },
        {
          Sid       = "DenyInsecureTransport"
          Effect    = "Deny"
          Principal = "*"
          Action    = "s3:*"
          Resource  = ["arn:aws:s3:::acme-finops", "arn:aws:s3:::acme-finops/*"]
          Condition = { Bool = { "aws:SecureTransport" = "false" } }
        },
      ]
    }
    error_message = "The bucket policy must let only the two Data Exports service principals put objects and read the policy, only for exports and definitions of the caller's own account, and must deny every request over plain HTTP."
  }
}

run "an_existing_export_needs_an_existing_bucket" {
  command = plan

  variables {
    cost_export_bucket_exists = false
    cost_export_exists        = true
  }

  expect_failures = [var.cost_export_exists]
}

run "an_existing_bucket_needs_its_name" {
  command = plan

  variables {
    cost_export_bucket_name = ""
  }

  expect_failures = [var.cost_export_bucket_exists]
}

run "a_prefix_holding_two_dots_is_refused" {
  command = plan

  variables {
    export_prefix = "finops/../costfluent"
  }

  expect_failures = [var.export_prefix]
}

run "a_prefix_holding_a_wildcard_is_refused" {
  command = plan

  variables {
    export_prefix = "finops/*"
  }

  expect_failures = [var.export_prefix]
}
