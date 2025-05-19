# AWS Glue ETL Pipeline with Terraform

This project demonstrates an AWS Glue ETL pipeline using Terraform for infrastructure as code. It showcases a common data processing workflow where files uploaded to an S3 bucket trigger a Glue job that converts them to Parquet format and catalogs them for analytics.

## Architecture

The pipeline consists of:

1. **S3 Buckets**:
   - Raw data bucket: Stores incoming CSV files
   - Parquet data bucket: Stores processed Parquet files

2. **AWS Glue Job**:
   - Triggered when new files are uploaded to the raw bucket
   - Converts CSV files to Parquet format
   - Saves the Parquet files to the destination bucket

3. **AWS Glue Crawler**:
   - Triggered after the Glue job completes
   - Catalogs the Parquet data for querying

4. **Event-Driven Workflow**:
   - S3 event notifications trigger a Lambda function when new files arrive
   - Lambda function starts the Glue job
   - EventBridge rule detects Glue job completion and triggers the crawler

## Deployment

### Prerequisites

- Terraform >= 1.0.0
- AWS CLI configured with appropriate permissions
- An S3 bucket for Terraform state (optional)

### Steps

1. Update the variables in `locals.tf` if needed
2. Initialize Terraform:
   ```
   terraform init
   ```
3. Apply the configuration:
   ```
   terraform apply
   ```

## Usage

1. Upload a CSV file to the `input/` prefix in the raw data bucket
2. The Glue job will automatically process the file and convert it to Parquet
3. The Glue crawler will catalog the data
4. Query the data using Athena or other AWS analytics services

## Customization

- Modify the Glue job script in `scripts/csv_to_parquet.py` to implement your specific ETL logic
- Adjust IAM permissions as needed for your use case
- Configure the S3 event notifications to filter for specific file types or prefixes 