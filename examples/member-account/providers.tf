terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.40.0, < 7.0.0"
    }
  }
}

# IAM is global; the region only picks an endpoint.
provider "aws" {
  region = "us-east-1"
}
