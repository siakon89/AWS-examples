# IAM role for Glue job
resource "aws_iam_role" "glue_job_role" {
  name = "${local.project_name}-glue-job-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

# Attach AWS managed policies for Glue
resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_job_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Custom policy for S3 access
resource "aws_iam_policy" "glue_s3_access" {
  name        = "${local.project_name}-glue-s3-access"
  description = "Policy for Glue job to access S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${module.raw_bucket.s3_bucket_id}",
          "arn:aws:s3:::${module.raw_bucket.s3_bucket_id}/*",
          "arn:aws:s3:::${module.parquet_bucket.s3_bucket_id}",
          "arn:aws:s3:::${module.parquet_bucket.s3_bucket_id}/*",
          "arn:aws:s3:::${module.artifacts_bucket.s3_bucket_id}",
          "arn:aws:s3:::${module.artifacts_bucket.s3_bucket_id}/*"
        ]
      }
    ]
  })
}

# Attach custom S3 policy to role
resource "aws_iam_role_policy_attachment" "glue_s3_access" {
  role       = aws_iam_role.glue_job_role.name
  policy_arn = aws_iam_policy.glue_s3_access.arn
}

# Custom policy for Lambda to start Glue jobs
resource "aws_iam_policy" "lambda_glue_access" {
  name        = "${local.project_name}-lambda-glue-access"
  description = "Policy for Lambda to start Glue jobs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:GetJobRuns",
          "glue:BatchStopJobRun"
        ]
        Resource = "arn:aws:glue:${local.region}:*:job/${aws_glue_job.csv_to_parquet.name}"
      }
    ]
  })
}

# Custom policy for Lambda to start Step Functions state machine
resource "aws_iam_policy" "lambda_step_functions_policy" {
  name        = "${local.project_name}-lambda-step-functions-policy"
  description = "Policy for Lambda to start Step Functions state machine"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = module.etl_state_machine.state_machine_arn
      }
    ]
  })
}

# Data policy document for Step Functions to invoke Glue jobs and crawlers
data "aws_iam_policy_document" "step_functions_glue_policy" {
  statement {
    effect = "Allow"
    actions = [
      "glue:StartJobRun",
      "glue:GetJobRun",
      "glue:GetJobRuns",
      "glue:BatchStopJobRun",
      "glue:StartCrawler",
      "glue:GetCrawler"
    ]
    resources = [
      "arn:aws:glue:${local.region}:*:job/${aws_glue_job.csv_to_parquet.name}",
      "arn:aws:glue:${local.region}:*:crawler/${aws_glue_crawler.parquet_crawler.name}"
    ]
  }
}
