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
}

run "export_read_covers_only_the_export_prefix" {
  command = apply

  variables {
    cost_export_bucket_name = "acme-export"
  }

  assert {
    condition = {
      for statement in jsondecode(aws_iam_role_policy.costfluent_export_read[0].policy).Statement :
      statement.Sid => {
        actions   = statement.Action
        resource  = statement.Resource
        condition = lookup(statement, "Condition", null)
      }
      } == {
      ExportBucketList = {
        actions   = ["s3:ListBucket"]
        resource  = "arn:aws:s3:::acme-export"
        condition = null
      }
      ExportObjectRead = {
        actions   = ["s3:GetObject"]
        resource  = "arn:aws:s3:::acme-export/costfluent/*"
        condition = null
      }
    }
    error_message = "The role must read objects only under costfluent/ and list the bucket itself, with no condition on either."
  }

  assert {
    condition     = aws_bcmdataexports_export.focus[0].export[0].destination_configurations[0].s3_destination[0].s3_prefix == output.settings.export_prefix
    error_message = "The export must be written under the prefix the settings output reports, which the policy reads."
  }

  assert {
    condition     = output.settings.export_prefix == "costfluent"
    error_message = "The export prefix must stay costfluent, the backend's default."
  }
}

run "no_bucket_grants_no_export_read" {
  command = apply

  assert {
    condition     = length(aws_iam_role_policy.costfluent_export_read) == 0
    error_message = "Without an export bucket the module must grant no S3 read."
  }

  assert {
    condition     = length(aws_bcmdataexports_export.carbon) == 0 && length(output.settings) == 0
    error_message = "A member account must get no carbon export and no settings: the management account's exports cover it."
  }
}

run "carbon_export_lands_beside_the_focus_export" {
  command = apply

  variables {
    cost_export_bucket_name   = "acme-export"
    cost_export_bucket_region = "eu-central-1"
  }

  assert {
    condition = alltrue([
      for field in ["s3_bucket", "s3_prefix", "s3_region"] :
      aws_bcmdataexports_export.carbon[0].export[0].destination_configurations[0].s3_destination[0][field] == aws_bcmdataexports_export.focus[0].export[0].destination_configurations[0].s3_destination[0][field]
    ])
    error_message = "The carbon export must land in the FOCUS export's bucket, region and prefix, where the role already reads."
  }

  assert {
    condition     = aws_bcmdataexports_export.carbon[0].export[0].destination_configurations[0].s3_destination[0].s3_output_configurations[0].format == "PARQUET"
    error_message = "The carbon export must be Parquet, the format Costfluent's carbon reader reads."
  }

  assert {
    condition = aws_bcmdataexports_export.carbon[0].export[0].data_query[0].query_statement == join("", [
      "SELECT last_refresh_timestamp, usage_period_start, usage_period_end, location, model_version, ",
      "payer_account_id, usage_account_id, product_code, region_code, ",
      "total_lbm_emissions_value, total_lbm_emissions_unit, total_mbm_emissions_value, total_mbm_emissions_unit, ",
      "total_scope_1_emissions_value, total_scope_1_emissions_unit, ",
      "total_scope_2_lbm_emissions_value, total_scope_2_lbm_emissions_unit, ",
      "total_scope_2_mbm_emissions_value, total_scope_2_mbm_emissions_unit, ",
      "total_scope_3_lbm_emissions_value, total_scope_3_lbm_emissions_unit, ",
      "total_scope_3_mbm_emissions_value, total_scope_3_mbm_emissions_unit FROM CARBON_EMISSIONS",
    ])
    error_message = "The carbon export must select every one of the 23 CARBON_EMISSIONS columns."
  }

  assert {
    condition     = try(length(aws_bcmdataexports_export.carbon[0].export[0].data_query[0].table_configurations), 0) == 0
    error_message = "CARBON_EMISSIONS has no table configurations; sending one fails the export."
  }

  assert {
    condition     = aws_bcmdataexports_export.carbon[0].export[0].name == "costfluent-carbon" && output.settings.carbon_export_name == "costfluent-carbon"
    error_message = "The carbon export must default to costfluent-carbon and report its name in the settings output."
  }
}

run "an_empty_carbon_export_name_creates_no_carbon_export" {
  command = apply

  variables {
    cost_export_bucket_name = "acme-export"
    carbon_export_name      = ""
  }

  assert {
    condition     = length(aws_bcmdataexports_export.carbon) == 0 && length(aws_bcmdataexports_export.focus) == 1
    error_message = "An empty carbon_export_name must skip the carbon export and keep the FOCUS one."
  }

  assert {
    condition     = !contains(keys(output.settings), "carbon_export_name")
    error_message = "Without a carbon export the settings output must not name one."
  }
}

run "a_carbon_export_named_like_the_focus_export_is_refused" {
  command = plan

  variables {
    cost_export_bucket_name = "acme-export"
    carbon_export_name      = "costfluent-focus"
  }

  expect_failures = [aws_bcmdataexports_export.carbon]
}
