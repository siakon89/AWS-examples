# Step Functions state machine definition
resource "aws_sfn_state_machine" "etl_state_machine" {
  name     = "${local.project_name}-etl-workflow"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = jsonencode({
    Comment = "ETL workflow to process CSV to Parquet and crawl the data",
    StartAt = "StartGlueJob",
    States = {
      "StartGlueJob" = {
        Type     = "Task",
        Resource = "arn:aws:states:::glue:startJobRun.sync",
        Parameters = {
          JobName = aws_glue_job.csv_to_parquet.name,
          Arguments = {
            "--input_path.$"  = "$.input_path",
            "--output_path.$" = "$.output_path"
          }
        },
        ResultPath = "$.glueJobResult",
        Next       = "StartGlueCrawler"
      },
      "StartGlueCrawler" = {
        Type     = "Task",
        Resource = "arn:aws:states:::aws-sdk:glue:startCrawler",
        Parameters = {
          Name = aws_glue_crawler.parquet_crawler.name
        },
        ResultPath = "$.glueCrawlerResult",
        Next       = "GetGlueCrawler"
      },
      "GetGlueCrawler" = {
        Type     = "Task",
        Resource = "arn:aws:states:::aws-sdk:glue:getCrawler",
        Parameters = {
          Name = aws_glue_crawler.parquet_crawler.name
        },
        ResultPath = "$.response.getCrawler"
        Next       = "IsCrawlerRunning"
      },
      "IsCrawlerRunning" = {
        Type = "Choice",
        Choices = [
          {
            Variable     = "$.response.getCrawler.Crawler.State",
            StringEquals = "RUNNING",
            Next         = "WaitCrawler"
          },
          {
            Variable     = "$.response.getCrawler.Crawler.State",
            StringEquals = "STOPPING",
            Next         = "WaitCrawler"
          },
          {
            Variable     = "$.response.getCrawler.Crawler.State",
            StringEquals = "READY",
            Next         = "Success"
          },
          {
            Variable     = "$.response.getCrawler.Crawler.State",
            StringEquals = "FAILED",
            Next         = "Fail"
          }
        ],
        Default = "Fail"
      },
      "WaitCrawler" = {
        Type    = "Wait",
        Seconds = 10,
        Next    = "GetGlueCrawler"
      },
      "Fail" = {
        Type  = "Fail",
        Error = "CrawlerFailed",
        Cause = "The Glue Crawler failed to complete successfully"
      },
      "Success" = {
        Type = "Pass",
        End  = true
      }
    }
  })
}

