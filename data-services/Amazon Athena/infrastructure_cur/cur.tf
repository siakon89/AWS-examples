# Create Glue crawler for CUR data
resource "aws_glue_crawler" "cur_crawler" {
  name          = "${local.name}-cur-crawler"
  database_name = aws_athena_database.athena_database.name
  role          = aws_iam_role.glue_crawler.arn
  table_prefix  = "cur_"  # This will prefix all tables created by this crawler
  
  s3_target {
    path = "s3://${local.cur_bucket_name}/${local.cur_prefix}"
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