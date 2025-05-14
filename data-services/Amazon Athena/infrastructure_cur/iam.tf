# IAM Resources
resource "aws_iam_role" "athena" {
  name = "${local.name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "athena.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_policy" "athena" {
  name        = "${local.name}-policy"
  path        = "/"
  description = "Policy for Athena showcase"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload",
          "s3:PutObject"
        ]
        Effect = "Allow"
        Resource = [
          module.athena_results_bucket.s3_bucket_arn,
          "${module.athena_results_bucket.s3_bucket_arn}/*",
          module.athena_data_bucket.s3_bucket_arn,
          "${module.athena_data_bucket.s3_bucket_arn}/*"
        ]
      },
      {
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution",
          "athena:GetWorkGroup",
          "athena:ListQueryExecutions"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:CreateTable",
          "glue:CreateDatabase"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "athena" {
  role       = aws_iam_role.athena.name
  policy_arn = aws_iam_policy.athena.arn
}

# Create IAM role for Glue crawler
resource "aws_iam_role" "glue_crawler" {
  name = "${local.name}-cur-crawler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# Create IAM policy for Glue crawler
resource "aws_iam_policy" "glue_crawler" {
  name        = "${local.name}-cur-crawler-policy"
  path        = "/"
  description = "Policy for Glue crawler to access CUR 2.0 data"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload",
          "s3:PutObject"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::${local.cur_bucket_name}",
          "arn:aws:s3:::${local.cur_bucket_name}/*"
        ]
      },
      {
        Action = [
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:CreateTable",
          "glue:CreateDatabase",
          "glue:BatchCreatePartition",
          "glue:BatchGetPartition",
          "glue:GetPartition",
          "glue:GetPartitions"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "glue_crawler" {
  role       = aws_iam_role.glue_crawler.name
  policy_arn = aws_iam_policy.glue_crawler.arn
}
