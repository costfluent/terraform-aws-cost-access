terraform {
  required_version = ">= 1.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.63"
    }
  }
}

# AWS Data Exports runs in us-east-1, so the export is created there; the bucket can be elsewhere
# through cost_export_bucket_region.
provider "aws" {
  region = "us-east-1"
}
