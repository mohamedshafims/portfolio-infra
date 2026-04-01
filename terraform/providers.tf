terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state with S3 native locking (Terraform 1.10+, no DynamoDB needed)
  # Uncomment after creating the bucket manually or via a separate config:
  #
  # backend "s3" {
  #   bucket       = "shafi-portfolio-tfstate"
  #   key          = "portfolio-infra/terraform.tfstate"
  #   region       = "us-east-1"
  #   use_lockfile = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "PortfolioInfra"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
