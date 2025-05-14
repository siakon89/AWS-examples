# Get AWS account ID for ECR repository URI
data "aws_caller_identity" "current_account" {}
data "aws_ecr_authorization_token" "token" {}
data "aws_region" "current_region" {}
