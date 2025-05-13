provider "aws" {
  region = local.aws_region

  s3_use_path_style = true
}