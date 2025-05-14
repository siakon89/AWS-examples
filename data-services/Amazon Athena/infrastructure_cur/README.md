# AWS Athena CUR Tagging Compliance Reporter

This project provides infrastructure and code for analyzing AWS Cost and Usage Report (CUR) 2.0 data using Amazon Athena, with a focus on resource tagging compliance.

## Overview

The solution consists of:

1. **Terraform Infrastructure** - Sets up AWS Glue crawler, Athena database, workgroups, and S3 buckets
2. **Sample Athena Queries** - Pre-built SQL queries for analyzing CUR 2.0 data
3. **Dockerized Lambda Function** - Automated reporting of tagging compliance via email and SNS

## Prerequisites

1. AWS account with appropriate permissions
2. Terraform installed locally
3. AWS CLI configured with access credentials
4. An existing CUR 2.0 export to S3
5. Docker installed locally (for building the Lambda container image)

## Setup Instructions

1. **Configure variables in `locals.tf`**:
   - Update `aws_region` to your preferred region
   - Set `name` to your project's name
   - Set `cur_bucket_name` to your CUR bucket name
   - Set `cur_prefix` to your CUR data prefix
   - Make sure `table_name` `cur_{data}`, `data` is the folder Glue is looking
   - Set `sender_email` and `recipient_emails` for the Lambda to send the cur report
   - Set the `tag_key_to_analyze` to the tag you want to make sure you are searching for 

3. **Initialize and apply Terraform**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Verify SES email verification**:
   - Check your email for the verification message from AWS
   - Click the verification link to confirm the email address

## Building and Deploying the Lambda Function

The Lambda function is containerized using Docker, which provides several benefits:
- Consistent runtime environment
- Ability to include custom dependencies
- Better isolation and security
- Easier local testing

### Docker Configuration

The Lambda function uses the following Docker configuration:
- Base image: `public.ecr.aws/lambda/python:3.12`
- Dependencies: Specified in `requirements.txt`
- Entry point: `untagged_resources_reporter.lambda_handler`

### Terraform Module

The solution uses the [terraform-aws-modules/lambda/aws](https://registry.terraform.io/modules/terraform-aws-modules/lambda/aws/latest) module to:
- Build and deploy the Docker image to Amazon ECR
- Create and configure the Lambda function
- Set up necessary IAM permissions
- Configure environment variables

## Lambda Function

The `lambdas/untagged_resources_reporter.py` Lambda function:

1. Queries Athena for tagging compliance data
2. Generates an HTML email report with:
   - Overall tagging compliance summary
   - Service-by-service tagging breakdown
   - List of most expensive untagged resources
3. Sends the report via Amazon SES
4. Publishes a notification to an SNS topic for further integrations

### Environment Variables

| Variable | Description |
|----------|-------------|
| DATABASE_NAME | Athena database name |
| TABLE_NAME | CUR table name (default: cur_data) |
| WORKGROUP | Athena workgroup name |
| OUTPUT_BUCKET | S3 bucket for query results |
| OUTPUT_PREFIX | Prefix for query results in S3 |
| SENDER_EMAIL | Verified SES email sender |
| RECIPIENT_EMAILS | Comma-separated email recipients |
| TAG_KEY_TO_ANALYZE | Tag key to analyze (default: user_creator) |
| SNS_TOPIC_ARN | ARN of SNS topic for notifications |

## Sample Athena Queries

The `sample_queries.sql` file contains various queries for analyzing CUR 2.0 data, including:

- Service-level cost breakdowns
- EC2 instance costs by type
- S3 costs by bucket
- Daily/monthly cost trends
- Regional cost analysis
- Reserved Instance and Savings Plan utilization
- Tag-based cost analysis
- Tagging compliance analysis

## Customization

### Change Tag Key to Analyze

1. Update `TAG_KEY_TO_ANALYZE` in the Lambda environment variables
2. Modify the sample queries as needed

### Modify Email Schedule

1. Update the CloudWatch Event Rule in `lambda.tf`
2. Change the `schedule_expression` to your preferred schedule using cron syntax

### Add Additional SNS Subscribers

1. Uncomment and modify the additional SNS subscription resources in `lambda.tf`
2. Add SMS, HTTP endpoints, or other protocols as needed

## Troubleshooting

- **Lambda Execution Issues**: Check CloudWatch Logs for the Lambda function
- **Email Delivery Problems**: Verify SES is properly configured and the email is verified
- **Athena Query Failures**: Check Athena query history in the AWS console
- **Docker Build Issues**: Check Docker build logs and ensure Docker is properly installed

## License

This project is licensed under the MIT License - see the LICENSE file for details. 