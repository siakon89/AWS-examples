import json
import boto3
import os
import urllib.parse
from datetime import datetime

# Initialize AWS clients
step_functions = boto3.client('stepfunctions')

def handler(event, context):
    
    # Get the Step Functions state machine ARN from environment variable
    state_machine_arn = os.environ.get('STATE_MACHINE_ARN')
    output_bucket = os.environ.get('OUTPUT_BUCKET')
    
    if not state_machine_arn:
        raise Exception("STATE_MACHINE_ARN environment variable is not set")
    

    bucket = event['Records'][0]['s3']['bucket']['name']
    key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'])  
    print(f"File uploaded: s3://{bucket}/{key}")
        
    # Prepare input and output paths for the state machine
    input_path = f"s3://{bucket}/{key}"
        
    # Create an output path with a timestamp to avoid overwriting
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    file_name = key.split('/')[-1].split('.')[0]
    output_path = f"s3://{output_bucket}/data/{file_name}_{timestamp}"
        
    print(f"Starting Step Functions state machine: {state_machine_arn}")
    print(f"Input path: {input_path}")
    print(f"Output path: {output_path}")
        
    # Prepare input for the state machine
    state_machine_input = {
        "input_path": input_path,
        "output_path": output_path
    }
        
    # Start the state machine execution
    response = step_functions.start_execution(
        stateMachineArn=state_machine_arn,
        name=f"ETL-{file_name}-{timestamp}",
        input=json.dumps(state_machine_input)
    )
        
    execution_arn = response['executionArn']
    print(f"Step Functions state machine started successfully. Execution ARN: {execution_arn}")
        
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Step Functions state machine triggered successfully',
            'executionArn': execution_arn
        })
    }
