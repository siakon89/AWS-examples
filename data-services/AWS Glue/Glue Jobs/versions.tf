terraform {
  required_version = "~> 1.11.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
  backend "s3" {
    bucket  = "thelastdev-tf-s3-state"
    key     = "glue-etl-demo/terraform.tfstate"
    region  = "eu-central-1"
    encrypt = true
  }
} 
