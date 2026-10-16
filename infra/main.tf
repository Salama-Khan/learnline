terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket       = "learnline-tfstate-369970405316"
    key          = "infra/terraform.tfstate"
    region       = "eu-west-2"
    profile      = "learnline"
    encrypt      = true
    use_lockfile = true
  }
}
provider "aws" {
  region              = var.region
  profile             = "learnline"
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
    }
  }
}

locals {
  raw_bucket_name = "${var.project}-raw-${var.account_id}"
}

resource "aws_s3_bucket" "raw" {
  bucket = local.raw_bucket_name
}

resource "aws_s3_bucket_public_access_block" "raw" {
  bucket                  = aws_s3_bucket.raw.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}