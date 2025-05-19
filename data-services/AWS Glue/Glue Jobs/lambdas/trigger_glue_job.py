import json
import boto3
import os
import urllib.parse
from datetime import datetime

# Initialize AWS clients
glue_client = boto3.client('glue')

def handler(event, context):
    """
    Lambda function that triggers a Glue job when a new file is uploaded to S3
    """
    print(f"Received event: {json.dumps(event)}")
    
    # Get the Glue job name from environment variable
    glue_job_name = os.environ.get('GLUE_JOB_NAME')
    
    # Process S3 event
    try:
        # Get bucket and key from the S3 event
        bucket = event['Records'][0]['s3']['bucket']['name']
        key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'])
        
        print(f"File uploaded: s3://{bucket}/{key}")
        
        # Prepare input and output paths for the Glue job
        input_path = f"s3://{bucket}/{key}"
        output_bucket = os.environ.get('OUTPUT_BUCKET')
        
        # Create an output path with a timestamp to avoid overwriting
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        file_name = key.split('/')[-1].split('.')[0]
        output_path = f"s3://{output_bucket}/data/{file_name}_{timestamp}"
        
        print(f"Starting Glue job: {glue_job_name}")
        print(f"Input path: {input_path}")
        print(f"Output path: {output_path}")
        
        # Start the Glue job with parameters
        response = glue_client.start_job_run(
            JobName=glue_job_name,
            Arguments={
                '--input_path': input_path,
                '--output_path': output_path
            }
        )
        
        job_run_id = response['JobRunId']
        print(f"Glue job started successfully. Job Run ID: {job_run_id}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Glue job triggered successfully',
                'jobRunId': job_run_id
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': f'Error triggering Glue job: {str(e)}'
            })
        } 