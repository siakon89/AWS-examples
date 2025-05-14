resource "aws_athena_workgroup" "athena_workgroup" {
  name        = local.name
  description = "Athena workgroup for ${local.name}"

  configuration {
    enforce_workgroup_configuration    = local.athena_workgroup.enforce_workgroup_configuration
    publish_cloudwatch_metrics_enabled = local.athena_workgroup.publish_cloudwatch_metrics_enabled
    bytes_scanned_cutoff_per_query     = local.athena_workgroup.bytes_scanned_cutoff_per_query

    engine_version {
      selected_engine_version = local.athena_workgroup.engine_version
    }

    result_configuration {
      output_location = "s3://${module.athena_results_bucket.s3_bucket_id}/"

      encryption_configuration {
        encryption_option = local.athena_workgroup.encryption_option
      }
    }
  }

  tags = local.tags
}

resource "aws_athena_database" "athena_database" {
  name   = replace(local.name, "-", "_")
  bucket = module.athena_data_bucket.s3_bucket_id
  force_destroy = true
  properties = {
    location = "s3://${module.athena_data_bucket.s3_bucket_id}/tables/"
  }
} 