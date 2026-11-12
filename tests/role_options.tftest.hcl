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

run "by_default_the_role_has_no_boundary_and_sits_at_the_root_path" {
  command = plan

  assert {
    condition     = aws_iam_role.costfluent.permissions_boundary == null
    error_message = "Without role_permissions_boundary_arn the role must carry no permissions boundary."
  }

  assert {
    condition     = aws_iam_role.costfluent.path == "/"
    error_message = "Without role_path the role must sit at /, where every earlier release put it."
  }
}

run "a_boundary_and_a_path_reach_the_role" {
  command = plan

  variables {
    role_permissions_boundary_arn = "arn:aws:iam::123456789012:policy/guardrails/CostfluentBoundary"
    role_path                     = "/costfluent/readers/"
  }

  assert {
    condition     = aws_iam_role.costfluent.permissions_boundary == "arn:aws:iam::123456789012:policy/guardrails/CostfluentBoundary"
    error_message = "role_permissions_boundary_arn must be the role's permissions boundary."
  }

  assert {
    condition     = aws_iam_role.costfluent.path == "/costfluent/readers/"
    error_message = "role_path must be the role's path."
  }
}

run "an_aws_managed_boundary_in_another_partition_is_accepted" {
  command = plan

  variables {
    role_permissions_boundary_arn = "arn:aws-us-gov:iam::aws:policy/ReadOnlyAccess"
  }

  assert {
    condition     = aws_iam_role.costfluent.permissions_boundary == "arn:aws-us-gov:iam::aws:policy/ReadOnlyAccess"
    error_message = "An AWS managed policy, in any partition, must be accepted as the boundary."
  }
}

run "a_path_of_512_characters_is_accepted" {
  command = plan

  variables {
    role_path = "/${join("", [for i in range(510) : "a"])}/"
  }

  assert {
    condition     = length(aws_iam_role.costfluent.path) == 512
    error_message = "A 512-character path is within IAM's limit and must be accepted."
  }
}

run "a_role_arn_as_the_boundary_is_refused" {
  command = plan

  variables {
    role_permissions_boundary_arn = "arn:aws:iam::123456789012:role/CostfluentBoundary"
  }

  expect_failures = [var.role_permissions_boundary_arn]
}

run "a_bare_policy_name_as_the_boundary_is_refused" {
  command = plan

  variables {
    role_permissions_boundary_arn = "CostfluentBoundary"
  }

  expect_failures = [var.role_permissions_boundary_arn]
}

run "a_boundary_with_a_short_account_id_is_refused" {
  command = plan

  variables {
    role_permissions_boundary_arn = "arn:aws:iam::12345678901:policy/CostfluentBoundary"
  }

  expect_failures = [var.role_permissions_boundary_arn]
}

run "a_path_without_its_leading_slash_is_refused" {
  command = plan

  variables {
    role_path = "costfluent/"
  }

  expect_failures = [var.role_path]
}

run "a_path_without_its_trailing_slash_is_refused" {
  command = plan

  variables {
    role_path = "/costfluent"
  }

  expect_failures = [var.role_path]
}

run "a_path_holding_a_space_is_refused" {
  command = plan

  variables {
    role_path = "/cost fluent/"
  }

  expect_failures = [var.role_path]
}

run "a_path_over_512_characters_is_refused" {
  command = plan

  variables {
    role_path = "/${join("", [for i in range(511) : "a"])}/"
  }

  expect_failures = [var.role_path]
}
