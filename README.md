# terraform-aws-cost-access

Grants [Costfluent](https://costfluent.com) read-only access to an AWS account's cost data.

The module creates an IAM role that Costfluent's connector role assumes, proving intent with the
external ID Costfluent issues to your organization. In a management (or standalone) account it
also creates a private S3 bucket and a daily FOCUS 1.2 Data Export into it, which is what Costfluent
reads. In a member account it creates only the role: its cost arrives through the management
account's export.

The same resources are available without Terraform as a CloudFormation template,
[`cloudformation/costfluent-aws.json`](cloudformation/costfluent-aws.json), which the Costfluent
console opens for you.

## Requirements

- Terraform >= 1.13 and the AWS provider ~> 6.63.
- The `aws` provider configured for `us-east-1`: AWS Data Exports runs only there. The bucket can
  be elsewhere through `cost_export_bucket_region`.
- Permission to create IAM roles and, in a management account, S3 buckets and Data Exports.

## Usage

The Costfluent provider's `costfluent_aws_provider_info` data source reads your organization's
external ID and the principal to trust; `costfluent_provider` then registers the connection. This
module does not embed the Costfluent provider, so no Costfluent token enters your AWS pipeline
unless you put one there.

```hcl
provider "aws" {
  region = "us-east-1"
}

data "costfluent_aws_provider_info" "this" {}

module "costfluent" {
  source  = "costfluent/cost-access/aws"
  version = "~> 0.2"

  costfluent_principal_arn = data.costfluent_aws_provider_info.this.principal_arn
  external_id              = data.costfluent_aws_provider_info.this.external_id
  cost_export_bucket_name  = "acme-costfluent-export" # omit in a member account
}

resource "costfluent_provider" "aws" {
  key         = "aws"
  name        = "AWS"
  credentials = module.costfluent.credentials
  settings    = module.costfluent.settings
}
```

`costfluent_provider` retries for up to three minutes while the new role propagates through IAM.

Without the Costfluent provider, copy the principal ARN and external ID from the Costfluent console
(**Connect AWS → More connection options → Terraform**), apply, and paste `credentials_json` and
the bucket into the console.

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `costfluent_principal_arn` | The Costfluent role your role trusts. | `string` | required |
| `external_id` | Your Costfluent organization's external ID (`cf-` and 32 hex characters). | `string` | required |
| `cost_export_bucket_name` | Bucket to create for the export. Empty in a member account. | `string` | `""` |
| `cost_export_bucket_region` | Region of the export bucket; an EU region keeps the files in the EU. | `string` | `"us-east-1"` |
| `export_name` | Name of the Data Export. | `string` | `"costfluent-focus"` |
| `role_name` | Name of the IAM role. | `string` | `"CostfluentBillingRole"` |
| `tags` | Tags applied to every resource. | `map(string)` | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `credentials` | `role_arn`, for `costfluent_provider`. |
| `credentials_json` | The same map as JSON, for the Costfluent console. |
| `settings` | `export_bucket`, `export_bucket_region`, `export_prefix` and `export_name`; empty in a member account. |
| `role_arn` | ARN of the role Costfluent assumes. |
| `account_id` | Account the role was created in, to confirm you targeted the right one. |

None of these authenticates. Access is the role's trust in Costfluent's principal together with
your organization's external ID, and Costfluent adds the external ID itself.

## Permissions granted

| Action | Resource | Why |
|---|---|---|
| `ce:GetCostAndUsage` | `*` | History before the export's first delivery, accounts with no export, and the monthly control total. |
| `organizations:ListAccounts` | `*` | Which member accounts a management account's cost covers. |
| `s3:ListBucket` | the export bucket | Finds the export's delivery for each month. |
| `s3:GetObject` | the export bucket's objects | Reads that delivery. |

Cost Explorer and Organizations have no resource-level permissions, so `*` is the only resource
those APIs accept; it grants no access to any resource in the account. The S3 grant exists only
when the module creates the bucket. The role is assumable only by the principal in
`costfluent_principal_arn`, and only with your organization's external ID.

## The export

- **Table:** `FOCUS_1_2_AWS`, every column, daily granularity, CSV with GZIP, overwritten per
  billing period, under the prefix `costfluent`.
- **Bucket:** private, public access blocked, SSE-S3, TLS required, and no expiry, so a later
  backfill still finds past months. Only AWS Data Exports may write to it.
- **Timing:** AWS delivers the first export within 24 to 72 hours. Until then, and for months before
  the export existed, Costfluent reads Cost Explorer. AWS can backfill up to 14 months of history
  into the export through a Billing support case.
- **Cost:** reading the export from Costfluent is S3 data transfer out on your bill; a daily export
  is typically megabytes a month.

## Upgrading from 0.1.x

0.2.0 is breaking. `costfluent_account_id` is replaced by `costfluent_principal_arn`, the trust
names one Costfluent role rather than a whole account, `external_id` must be the value Costfluent
issued to your organization, `ce:ListCostAllocationTags` is no longer granted, and `credentials`
no longer carries `external_id`. `max_session_duration` is gone: chained sessions last an hour.

## Security

- Nothing here is a long-lived key. Every session Costfluent assumes is temporary.
- `terraform destroy` removes the role and revokes Costfluent's access. The bucket and export go
  with it unless S3 refuses to delete a non-empty bucket, which keeps your history.

## License

MIT — see [LICENSE](LICENSE).
