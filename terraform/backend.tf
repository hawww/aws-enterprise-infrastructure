terraform {
  required_version = ">= 1.5.0"

  # Configure S3 backend for state management
  # Before applying, create the S3 bucket and DynamoDB table:
  # 
  # AWS CLI commands to setup:
  # aws s3api create-bucket --bucket enterprise-tfstate-us-east-1 --region us-east-1
  # aws s3api put-bucket-versioning --bucket enterprise-tfstate-us-east-1 --versioning-configuration Status=Enabled
  # aws s3api put-bucket-server-side-encryption-configuration --bucket enterprise-tfstate-us-east-1 --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
  # aws dynamodb create-table --table-name enterprise-tflock --attribute-definitions AttributeName=LockID,AttributeType=S   --key-schema AttributeName=LockID,KeyType=HASH --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 --region us-east-1
  #
  # Then uncomment the backend block below and update the bucket name and table name:
  #
  backend "s3" {
    bucket         = "enterprise-tfstate-us-east-1"
    key            = "enterprise-infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "enterprise-tflock"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.26"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = var.project_name
      CreatedDate = timestamp()
    }
  }
}

provider "aws" {
  alias  = "dr"
  region = var.aws_region_dr
}