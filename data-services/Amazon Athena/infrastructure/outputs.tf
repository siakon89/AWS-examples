output "athena_workgroup_name" {
  description = "The name of the Athena workgroup"
  value       = aws_athena_workgroup.athena_workgroup.name
}

output "athena_database_name" {
  description = "The name of the Athena database"
  value       = aws_athena_database.athena_database.name
}

output "athena_results_bucket" {
  description = "The S3 bucket for Athena query results"
  value       = module.athena_results_bucket.s3_bucket_id
}

output "athena_data_bucket" {
  description = "The S3 bucket for Athena data"
  value       = module.athena_data_bucket.s3_bucket_id
}

output "athena_iam_role_arn" {
  description = "The ARN of the IAM role for Athena"
  value       = aws_iam_role.athena.arn
}
