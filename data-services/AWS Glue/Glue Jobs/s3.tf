# Raw data bucket - for storing incoming files
module "raw_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.8"

  bucket = "${local.project_name}-raw-data-${local.environment}"

  force_destroy = true

  versioning = {
    enabled = true
  }

  tags = local.tags
}

# Parquet data bucket - for storing processed files
module "parquet_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.8"

  bucket = "${local.project_name}-parquet-data-${local.environment}"

  force_destroy = true

  versioning = {
    enabled = true
  }

  tags = local.tags
}

# Parquet data bucket - for storing processed files
module "artifacts_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.8"

  bucket = "${local.project_name}-glue-artifacts-${local.environment}"

  force_destroy = true

  versioning = {
    enabled = true
  }

  tags = local.tags
}
