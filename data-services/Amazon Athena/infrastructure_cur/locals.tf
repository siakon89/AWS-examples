locals {
  # AWS Region
  aws_region = "eu-central-1"

  # Resource naming
  name        = "<your-project-name>"
  environment = "demo"

  # Tags
  tags = {
    Environment = local.environment
    Project     = "Athena Showcase"
    Terraform   = "true"
  }

  # CUR configuration
  cur_bucket_name = "<your-cur-bucket-name>"
  cur_prefix      = "<your-cur-prefix>"
  table_name      = "cur_data"

  # Athena Workgroup configuration
  athena_workgroup = {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    encryption_option                  = "SSE_S3"
    bytes_scanned_cutoff_per_query     = 0
    # Available engine versions:
    # - "AUTO" (automatically selects the latest engine version)
    # - "Athena engine version 3" (latest SQL engine version)
    # - "PySpark engine version 3" (for running PySpark queries)
    engine_version = "Athena engine version 3"
  }

  # Lambda function configuration
  lambda_name        = "${local.name}-untagged-resources-reporter"
  lambda_description = "Lambda function to report on untagged AWS resources using Athena CUR data"

  # Email configuration
  sender_email     = "<the-sender-email>" # Change this to your verified SES email
  recipient_emails = "<the-recipient-emails>"    # Comma-separated list of email recipients

  # SNS Topic
  sns_topic_name = "${local.name}-tagging-compliance"

  # Docker image config
  ecr_repository_name = "${local.name}-lambda-image"
  tag_key_to_analyze  = "<the-tag-key-to-analyze>"
}
