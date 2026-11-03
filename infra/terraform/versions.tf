terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  # Partial S3 backend. scripts/ensure-tf-backend.sh (and the deploy
  # workflow) supply bucket, region, and DynamoDB lock table.
  backend "s3" {
    key     = "devops-assignment/terraform.tfstate"
    encrypt = true
  }
}
