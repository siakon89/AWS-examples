# ECR Docker image for Lambda
module "docker_image" {
  source = "terraform-aws-modules/lambda/aws//modules/docker-build"

  ecr_repo = module.ecr.repository_name
  # image_tag       = "latest"
  source_path = "${path.module}/lambdas"

  # cache_from = ["${module.ecr.repository_url}:latest"]
  # Use the pre-built image from ECR
  use_image_tag = true
}

module "ecr" {
  source = "terraform-aws-modules/ecr/aws"

  repository_name         = "${local.project_name}-ecr"
  repository_force_delete = true

  create_lifecycle_policy = false

  repository_lambda_read_access_arns = [module.trigger_step_function.lambda_function_arn]
}


# Lambda function using terraform-aws-modules/lambda/aws module
module "trigger_step_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.20"

  function_name = "${local.project_name}-trigger-step-function"
  description   = "Lambda function to trigger Step Function when a file is uploaded to S3"

  # Docker image config
  create_package = false
  image_uri      = module.docker_image.image_uri
  package_type   = "Image"

  # Lambda settings
  timeout     = 300
  memory_size = 512

  # Environment variables
  environment_variables = {
    GLUE_JOB_NAME     = aws_glue_job.csv_to_parquet.name
    OUTPUT_BUCKET     = module.parquet_bucket.s3_bucket_id
    STATE_MACHINE_ARN = module.etl_state_machine.state_machine_arn
  }

  image_config_command = ["trigger_step_function.handler"]

  # IAM policy statements
  attach_policies = true
  policies = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    aws_iam_policy.lambda_glue_access.arn,
    aws_iam_policy.lambda_step_functions_policy.arn
  ]
  number_of_policies = 3

  tags = local.tags
}

# S3 event notification to trigger Lambda
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = module.raw_bucket.s3_bucket_id

  lambda_function {
    lambda_function_arn = module.trigger_step_function.lambda_function_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "input/"
    filter_suffix       = ".csv"
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

# Permission for S3 to invoke Lambda
resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = module.trigger_step_function.lambda_function_arn
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${module.raw_bucket.s3_bucket_id}"
}
