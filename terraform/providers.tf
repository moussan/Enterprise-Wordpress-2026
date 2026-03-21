terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  backend "s3" {} # Values passed via CLI or GitHub Actions
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Enterprise-Wordpress"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
