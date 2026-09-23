terraform {
  required_version = ">= 1.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.63"
    }
  }
}

# IAM is global; the region only picks an endpoint.
provider "aws" {
  region = "us-east-1"
}
