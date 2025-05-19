# Upload the Glue job script to S3
resource "aws_s3_object" "glue_job_script" {
  bucket = module.artifacts_bucket.s3_bucket_id
  key    = "scripts/csv_to_parquet.py"
  source = "${path.module}/scripts/csv_to_parquet.py"
  etag   = filemd5("${path.module}/scripts/csv_to_parquet.py")
}

# Glue job definition
resource "aws_glue_job" "csv_to_parquet" {
  depends_on = [aws_s3_object.glue_job_script]
  name       = "${local.project_name}-csv-to-parquet"
  role_arn   = aws_iam_role.glue_job_role.arn

  command {
    name            = "glueetl"
    script_location = "s3://${module.artifacts_bucket.s3_bucket_id}/${aws_s3_object.glue_job_script.key}"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--TempDir"                          = "s3://${module.parquet_bucket.s3_bucket_id}/temp/"
    "--input_path"  = "s3://${module.raw_bucket.s3_bucket_id}/input/"
    "--output_path" = "s3://${module.parquet_bucket.s3_bucket_id}/data/"
  }

  execution_property {
    max_concurrent_runs = 1
  }

  glue_version      = "5.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 10 # minutes
}

# Glue crawler to catalog the parquet data
resource "aws_glue_crawler" "parquet_crawler" {
  name          = "${local.project_name}-parquet-crawler"
  role          = aws_iam_role.glue_job_role.arn
  database_name = aws_glue_catalog_database.parquet_db.name

  s3_target {
    path = "s3://${module.parquet_bucket.s3_bucket_id}/data/"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
    }
  })
}

# Glue catalog database
resource "aws_glue_catalog_database" "parquet_db" {
  name        = "${local.project_name}_parquet_db"
  description = "Database for parquet data processed by Glue job"
}
