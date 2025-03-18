locals {
  common_tags = {
    Project     = "cp-planta"
    ManagedBy   = "terraform"
    Owner       = "ages"
  }
}

terraform {
  required_version = ">= 0.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 3.0"
    }
  }

  # # backend config to persist state
  # backend "s3" {
  #   bucket = "cp-planta-terraform-state"
  #   key    = "terraform.tfstate"
  #   region = "us-east-2"
  # }
}

