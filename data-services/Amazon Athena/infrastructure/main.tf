module "athena_results_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.8"

  bucket = "${local.name}-query-results"
  force_destroy = true
  acl = "private"

  # Add ownership controls
  control_object_ownership = true
  object_ownership         = "ObjectWriter"

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
