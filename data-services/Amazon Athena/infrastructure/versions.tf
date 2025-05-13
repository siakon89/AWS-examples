terraform {
  required_version = "~> 1.11.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
      bucket = "thelastdev-tf-s3-state"
      key    = "athena-showcase/terraform.tfstate"
      region = "eu-central-1"
      encrypt = true
  }
}
