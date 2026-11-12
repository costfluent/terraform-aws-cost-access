terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.40.0, < 7.0.0"
    }
  }
}

# AWS Data Exports runs in us-east-1, so the export is created there; the bucket can be elsewhere
# through cost_export_bucket_region.
provider "aws" {
  region = "us-east-1"
}
