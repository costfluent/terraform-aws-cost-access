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
  cost_export_bucket_name  = "acme-finops"
}

run "the_longest_names_each_input_allows_are_accepted" {
  command = plan

  variables {
    costfluent_principal_arn = "arn:aws-us-gov:iam::123456789012:role/service-role/costfluent-connector"
    cost_export_bucket_name  = join("", ["a", join("", [for i in range(61) : "b"]), "c"])
    role_name                = join("", [for i in range(64) : "r"])
    export_name              = join("", [for i in range(128) : "f"])
    carbon_export_name       = join("", [for i in range(128) : "c"])
  }

  assert {
    condition = alltrue([
      length(aws_iam_role.costfluent.name) == 64,
      length(aws_s3_bucket.export[0].bucket) == 63,
      length(aws_bcmdataexports_export.focus[0].export[0].name) == 128,
      length(aws_bcmdataexports_export.carbon[0].export[0].name) == 128,
    ])
    error_message = "A 64-character role name, a 63-character bucket name and 128-character export names are within AWS's limits and must be accepted as given."
  }
}

run "an_external_id_not_issued_by_costfluent_is_refused" {
  command = plan

  variables {
    external_id = "cf-123"
  }

  expect_failures = [var.external_id]
}

run "an_external_id_in_upper_case_is_refused" {
  command = plan

  variables {
    external_id = "cf-0123456789ABCDEF0123456789ABCDEF"
  }

  expect_failures = [var.external_id]
}

run "a_principal_that_is_not_a_role_is_refused" {
  command = plan

  variables {
    costfluent_principal_arn = "*"
  }

  expect_failures = [var.costfluent_principal_arn]
}

run "a_user_principal_is_refused" {
  command = plan

  variables {
    costfluent_principal_arn = "arn:aws:iam::123456789012:user/costfluent-connector"
  }

  expect_failures = [var.costfluent_principal_arn]
}

run "a_bucket_name_with_upper_case_is_refused" {
  command = plan

  variables {
    cost_export_bucket_name = "Acme-Finops"
  }

  expect_failures = [var.cost_export_bucket_name]
}

run "a_bucket_name_over_63_characters_is_refused" {
  command = plan

  variables {
    cost_export_bucket_name = join("", [for i in range(64) : "b"])
  }

  expect_failures = [var.cost_export_bucket_name]
}

run "a_bucket_name_under_3_characters_is_refused" {
  command = plan

  variables {
    cost_export_bucket_name = "ab"
  }

  expect_failures = [var.cost_export_bucket_name]
}

run "a_role_name_over_64_characters_is_refused" {
  command = plan

  variables {
    role_name = join("", [for i in range(65) : "r"])
  }

  expect_failures = [var.role_name]
}

run "an_empty_role_name_is_refused" {
  command = plan

  variables {
    role_name = ""
  }

  expect_failures = [var.role_name]
}

run "an_export_name_with_a_slash_is_refused" {
  command = plan

  variables {
    export_name = "finops/focus"
  }

  expect_failures = [var.export_name]
}

run "an_empty_export_name_is_refused" {
  command = plan

  variables {
    export_name = ""
  }

  expect_failures = [var.export_name]
}

run "a_carbon_export_name_with_a_slash_is_refused" {
  command = plan

  variables {
    carbon_export_name = "finops/carbon"
  }

  expect_failures = [var.carbon_export_name]
}

run "a_focus_export_outside_us_east_1_is_refused" {
  command = plan

  variables {
    carbon_export_name = ""
  }

  override_data {
    target = data.aws_region.current
    values = {
      region = "eu-central-1"
    }
  }

  expect_failures = [aws_bcmdataexports_export.focus]
}

# An existing FOCUS export leaves the carbon export the only one the module creates, so this run
# reaches the carbon export's own region precondition and no other.
run "a_carbon_export_outside_us_east_1_is_refused" {
  command = plan

  variables {
    cost_export_bucket_exists = true
    cost_export_exists        = true
  }

  override_data {
    target = data.aws_region.current
    values = {
      region = "eu-central-1"
    }
  }

  expect_failures = [aws_bcmdataexports_export.carbon]
}
