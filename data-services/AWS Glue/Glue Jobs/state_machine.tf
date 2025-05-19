# Step Functions state machine definition
module "etl_state_machine" {
  source  = "terraform-aws-modules/step-functions/aws"
  version = "~> 4.2.1"

  name = "${local.project_name}-etl-workflow"

  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.step_functions_glue_policy.json

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
