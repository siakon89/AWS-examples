# Create Glue crawler for CUR data
resource "aws_glue_crawler" "demo_crawler" {
  name          = "${local.name}-demo-crawler"
  database_name = aws_athena_database.athena_database.name
  role          = aws_iam_role.glue_crawler.arn
  table_prefix  = "demo_"  # This will prefix all tables created by this crawler

  s3_target {
    path = "s3://${module.athena_data_bucket.s3_bucket_id}/${local.sample_data_prefix}"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
      Tables     = { AddOrUpdateBehavior = "MergeNewColumns" }
    }
  })

  tags = local.tags
} 