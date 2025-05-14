# ECR Docker image for Lambda
module "docker_image" {
  source = "terraform-aws-modules/lambda/aws//modules/docker-build"

  ecr_repo        = module.ecr.repository_name
  # image_tag       = "latest"
  source_path     = "${path.module}/lambdas"

  # cache_from = ["${module.ecr.repository_url}:latest"]
  # Use the pre-built image from ECR
  use_image_tag = true
}

module "ecr" {
  source = "terraform-aws-modules/ecr/aws"

  repository_name         = local.ecr_repository_name
  repository_force_delete = true

  create_lifecycle_policy = false

  repository_lambda_read_access_arns = [module.lambda_function.lambda_function_arn]
}


# Lambda function using terraform-aws-modules/lambda/aws module
module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.20"

  function_name = local.lambda_name
  description   = local.lambda_description

  # Docker image config
  create_package = false
  image_uri      = module.docker_image.image_uri
  package_type   = "Image"

  # Lambda settings
  timeout     = 300
  memory_size = 512

  # Environment variables
  environment_variables = {
    DATABASE_NAME      = aws_athena_database.athena_database.name
    TABLE_NAME         = local.table_name
    WORKGROUP          = aws_athena_workgroup.athena_workgroup.name
    OUTPUT_BUCKET      = module.athena_results_bucket.s3_bucket_id
    SENDER_EMAIL       = local.sender_email
    RECIPIENT_EMAILS   = local.recipient_emails
    TAG_KEY_TO_ANALYZE = local.tag_key_to_analyze
  }

  # IAM policy statements
  attach_policy_statements = true
  policy_statements = {
    cloudwatch_logs = {
      effect = "Allow",
      actions = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      resources = ["arn:aws:logs:*:*:*"]
    },
    athena = {
      effect = "Allow",
      actions = [
        "athena:StartQueryExecution",
        "athena:GetQueryExecution",
        "athena:GetQueryResults"
      ],
      resources = ["*"]
    },
    glue = {
      effect = "Allow",
      actions = [
        "glue:GetDatabase",
        "glue:GetDatabases",
        "glue:GetTable",
        "glue:GetTables",
        "glue:GetPartition",
        "glue:GetPartitions",
        "glue:BatchGetPartition"
      ],
      resources = ["*"]
    },
    s3 = {
      effect = "Allow",
      actions = [
        "s3:GetObject",
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:PutObject"
      ],
      resources = [
        "arn:aws:s3:::${module.athena_results_bucket.s3_bucket_id}",
        "arn:aws:s3:::${module.athena_results_bucket.s3_bucket_id}/*"
      ]
    },
     s3_cur = {
      effect = "Allow",
      actions = [
        "s3:GetObject",
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      resources = [
        "arn:aws:s3:::${local.cur_bucket_name}",
        "arn:aws:s3:::${local.cur_bucket_name}/*"
      ]
    },
    ses = {
      effect = "Allow",
      actions = [
        "ses:SendEmail",
        "ses:SendRawEmail"
      ],
      resources = ["*"]
    }
  }

  tags = local.tags
}

# CloudWatch Event Rule to trigger Lambda on a schedule (monthly)
resource "aws_cloudwatch_event_rule" "monthly_trigger" {
  name                = "lambda-monthly-trigger"
  description         = "Triggers the untagged resources reporter Lambda function on the 3rd day of each month"
  schedule_expression = "cron(0 8 3 * ? *)" # 8:00 AM UTC on the 3rd day of each month

  tags = local.tags
}

# CloudWatch Event Target
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.monthly_trigger.name
  target_id = "TriggerLambda"
  arn       = module.lambda_function.lambda_function_arn
}

# Lambda permission to allow CloudWatch Events to invoke the function
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_function.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.monthly_trigger.arn
}
