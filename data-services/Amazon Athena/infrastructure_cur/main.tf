module "athena_results_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.8"

  bucket = "${local.name}-query-results"
  force_destroy = true
  acl = "private"

  # Add ownership controls
  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  # Configure lifecycle rules
  lifecycle_rule = [
    {
      id      = "query-results-expiration"
      enabled = true
      
      # Add required filter with prefix
      filter = {
        prefix = ""  # Empty prefix means apply to all objects
      }
      
      # Expire objects after 7 days
      expiration = {
        days = 7
      }
      
      # Clean up incomplete multipart uploads
      abort_incomplete_multipart_upload_days = 1
      
      # Keep noncurrent versions for 7 days
      noncurrent_version_expiration = {
        days = 7
      }
    }
  ]

  tags = local.tags
}

# Create a bucket for sample data
module "athena_data_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.8"

  bucket = "${local.name}-data"
  force_destroy = true
  acl = "private"

  # Add ownership controls
  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  tags = local.tags
}
