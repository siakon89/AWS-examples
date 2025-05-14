import boto3
import time
import json
import os
import csv
import io
import datetime
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication

# Environment variables
DATABASE_NAME = os.environ.get('DATABASE_NAME', '')
TABLE_NAME = os.environ.get('TABLE_NAME', '')
WORKGROUP = os.environ.get('WORKGROUP', '')
OUTPUT_BUCKET = os.environ.get('OUTPUT_BUCKET', '')
SENDER_EMAIL = os.environ.get('SENDER_EMAIL', '')
RECIPIENT_EMAILS = os.environ.get('RECIPIENT_EMAILS', '').split(',')
TAG_KEY_TO_ANALYZE = os.environ.get('TAG_KEY_TO_ANALYZE', '')
BILLING_PERIOD = os.environ.get('BILLING_PERIOD', datetime.datetime.now().replace(day=1).strftime('%Y-%m-%d'))

def lambda_handler(event, context):
    """
    Main Lambda handler function that queries Athena and sends email reports
    """
    try:
        # Initialize clients
        athena_client = boto3.client('athena')
        s3_client = boto3.client('s3')
        ses_client = boto3.client('ses')
        
        # Execute queries
        print("Starting Athena queries...")
        tagged_vs_untagged_results = run_tagged_vs_untagged_query(athena_client, s3_client)
        expensive_untagged_results = run_expensive_untagged_query(athena_client, s3_client)
        
        # Generate and send email
        print("Generating and sending email report...")
        # print(tagged_vs_untagged_results)
        # print(expensive_untagged_results)
        send_email_report(ses_client, tagged_vs_untagged_results, expensive_untagged_results)
        
        return {
            'statusCode': 200,
            'body': json.dumps('Successfully executed CUR analysis and sent email report')
        }
    except Exception as e:
        print(f"Error executing Lambda function: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }

def run_tagged_vs_untagged_query(athena_client, s3_client):
    """
    Execute query 15 - Tagged vs. Untagged Resource Distribution by Service
    """
    query = f"""
    WITH tag_key_to_search AS (
        SELECT '{TAG_KEY_TO_ANALYZE}' AS key
    ),
    resource_counts AS (
        SELECT
            line_item_product_code AS service,
            line_item_resource_id AS resource_id,
            MAX(CASE WHEN CARDINALITY(MAP_KEYS(resource_tags)) > 0 THEN 1 ELSE 0 END) AS is_tagged,
            MAX(CASE WHEN resource_tags[(SELECT key FROM tag_key_to_search)] IS NOT NULL 
                     AND resource_tags[(SELECT key FROM tag_key_to_search)] <> '' 
                     THEN 1 ELSE 0 END) AS has_specific_tag,
            SUM(line_item_unblended_cost) AS resource_cost
        FROM {DATABASE_NAME}.{TABLE_NAME}
        WHERE
            line_item_resource_id <> '' AND
            bill_billing_period_start_date = DATE '{BILLING_PERIOD}' AND
            line_item_line_item_type != 'Credit' AND
            line_item_line_item_type != 'Refund' AND
            line_item_line_item_type = 'Usage' AND
            line_item_resource_id NOT LIKE '%management%' AND
            line_item_resource_id NOT LIKE '%overhead%'
        GROUP BY 1, 2
    )
    SELECT
        service,
        COUNT(DISTINCT resource_id) AS total_resources,
        SUM(resource_cost) AS total_cost,
        
        -- Tagged resources metrics
        SUM(CASE WHEN is_tagged = 1 THEN 1 ELSE 0 END) AS tagged_resources,
        ROUND(100.0 * SUM(CASE WHEN is_tagged = 1 THEN 1 ELSE 0 END) / COUNT(DISTINCT resource_id), 2) AS tagged_resources_percent,
        SUM(CASE WHEN is_tagged = 1 THEN resource_cost ELSE 0 END) AS tagged_cost,
        ROUND(100.0 * SUM(CASE WHEN is_tagged = 1 THEN resource_cost ELSE 0 END) / SUM(resource_cost), 2) AS tagged_cost_percent,
        
        -- Untagged resources metrics
        SUM(CASE WHEN is_tagged = 0 THEN 1 ELSE 0 END) AS untagged_resources,
        ROUND(100.0 * SUM(CASE WHEN is_tagged = 0 THEN 1 ELSE 0 END) / COUNT(DISTINCT resource_id), 2) AS untagged_resources_percent,
        SUM(CASE WHEN is_tagged = 0 THEN resource_cost ELSE 0 END) AS untagged_cost,
        ROUND(100.0 * SUM(CASE WHEN is_tagged = 0 THEN resource_cost ELSE 0 END) / SUM(resource_cost), 2) AS untagged_cost_percent,
        
        -- Specific tag metrics
        SUM(CASE WHEN has_specific_tag = 1 THEN 1 ELSE 0 END) AS resources_with_specific_tag,
        ROUND(100.0 * SUM(CASE WHEN has_specific_tag = 1 THEN 1 ELSE 0 END) / COUNT(DISTINCT resource_id), 2) AS specific_tag_resources_percent,
        SUM(CASE WHEN has_specific_tag = 1 THEN resource_cost ELSE 0 END) AS specific_tag_cost,
        ROUND(100.0 * SUM(CASE WHEN has_specific_tag = 1 THEN resource_cost ELSE 0 END) / SUM(resource_cost), 2) AS specific_tag_cost_percent
    FROM resource_counts
    GROUP BY 1
    HAVING COUNT(DISTINCT resource_id) > 0
    ORDER BY total_cost DESC
    """
    
    return execute_athena_query(athena_client, s3_client, query, "tagged_vs_untagged")

def run_expensive_untagged_query(athena_client, s3_client):
    """
    Execute query for most expensive untagged resources
    """
    query = f"""
    SELECT
        line_item_product_code AS service,
        line_item_resource_id AS resource_id,
        product_region_code AS region,
        product['instance_type'] AS instance_type,
        product['product_name'] AS product_name,
        line_item_usage_type AS usage_type,
        SUM(line_item_unblended_cost) AS cost
    FROM {DATABASE_NAME}.{TABLE_NAME}
    WHERE
        CARDINALITY(MAP_KEYS(resource_tags)) = 0 AND
        line_item_resource_id <> '' AND
        line_item_line_item_type = 'Usage' AND
        bill_billing_period_start_date = DATE '{BILLING_PERIOD}' AND
        line_item_resource_id NOT LIKE '%management%' AND
        line_item_resource_id NOT LIKE '%overhead%'
    GROUP BY 1, 2, 3, 4, 5, 6
    HAVING SUM(line_item_unblended_cost) > 0
    ORDER BY 7 DESC
    LIMIT 50
    """
    
    return execute_athena_query(athena_client, s3_client, query, "expensive_untagged")

def execute_athena_query(athena_client, s3_client, query, query_name):
    """
    Execute an Athena query and wait for its completion
    """
    timestamp = int(time.time())
    
    # Start the query execution
    response = athena_client.start_query_execution(
        QueryString=query,
        QueryExecutionContext={
            'Database': DATABASE_NAME
        },
        WorkGroup=WORKGROUP
    )
    
    query_execution_id = response['QueryExecutionId']
    print(f"Started query execution with ID: {query_execution_id}")
    
    # Wait for query to complete
    state = 'RUNNING'
    max_retries = 60  # 5 minutes with 5-second intervals
    retry_count = 0
    
    while retry_count < max_retries and state in ['RUNNING', 'QUEUED']:
        response = athena_client.get_query_execution(QueryExecutionId=query_execution_id)
        state = response['QueryExecution']['Status']['State']
        
        if state in ['RUNNING', 'QUEUED']:
            time.sleep(5)
            retry_count += 1
    
    if state != 'SUCCEEDED':
        error_message = response['QueryExecution']['Status'].get('StateChangeReason', 'Unknown error')
        raise Exception(f"Query failed with state {state}: {error_message}")
    
    # Get query results
    result_key = f"{query_execution_id}.csv"
    
    # Read CSV from S3
    response = s3_client.get_object(Bucket=OUTPUT_BUCKET, Key=result_key)
    csv_content = response['Body'].read().decode('utf-8')
    
    # Parse CSV content using the csv module
    csv_file = io.StringIO(csv_content)
    csv_reader = csv.DictReader(csv_file)
    
    # Convert to list of dictionaries
    results = []
    for row in csv_reader:
        # Convert numeric strings to appropriate types
        processed_row = {}
        for key, value in row.items():
            # Try to convert to float or int if possible
            try:
                if '.' in value:
                    processed_row[key] = float(value)
                else:
                    processed_row[key] = int(value)
            except (ValueError, TypeError):
                processed_row[key] = value
        results.append(processed_row)
    
    return results

def send_email_report(ses_client, tagged_vs_untagged_results, expensive_untagged_results):
    """
    Generate and send an email report with the query results
    """
    # Create message container
    msg = MIMEMultipart()
    msg['Subject'] = f'AWS Cost and Usage Report - Tagging Analysis ({BILLING_PERIOD})'
    msg['From'] = SENDER_EMAIL
    msg['To'] = ', '.join(RECIPIENT_EMAILS)
    
    # Create HTML email body
    html_body = f"""
    <html>
    <head>
        <style>
            table {{
                border-collapse: collapse;
                width: 100%;
                margin-bottom: 20px;
            }}
            th, td {{
                border: 1px solid #ddd;
                padding: 8px;
                text-align: left;
            }}
            th {{
                background-color: #f2f2f2;
            }}
            tr:nth-child(even) {{
                background-color: #f9f9f9;
            }}
            .summary {{
                margin-bottom: 20px;
                padding: 10px;
                background-color: #e6f7ff;
                border-left: 5px solid #1890ff;
            }}
            .warning {{
                color: #d46b08;
                font-weight: bold;
            }}
        </style>
    </head>
    <body>
        <h1>AWS Cost and Usage Report - Tagging Analysis</h1>
        <p>Billing Period: {BILLING_PERIOD}</p>
        <p>Tag Key Analyzed: {TAG_KEY_TO_ANALYZE}</p>
        
        <h2>1. Tagged vs. Untagged Resources by Service</h2>
    """
    
    # Calculate overall tagging metrics
    total_resources = sum(int(item.get('total_resources', 0)) for item in tagged_vs_untagged_results)
    total_cost = sum(float(item.get('total_cost', 0)) for item in tagged_vs_untagged_results)
    tagged_resources = sum(int(item.get('tagged_resources', 0)) for item in tagged_vs_untagged_results)
    tagged_cost = sum(float(item.get('tagged_cost', 0)) for item in tagged_vs_untagged_results)
    untagged_resources = sum(int(item.get('untagged_resources', 0)) for item in tagged_vs_untagged_results)
    untagged_cost = sum(float(item.get('untagged_cost', 0)) for item in tagged_vs_untagged_results)
    
    # Add summary section
    tagged_resources_percent = round(100.0 * tagged_resources / total_resources, 2) if total_resources > 0 else 0
    tagged_cost_percent = round(100.0 * tagged_cost / total_cost, 2) if total_cost > 0 else 0
    
    html_body += f"""
        <div class="summary">
            <h3>Overall Tagging Summary</h3>
            <p>Total Resources: {total_resources} | Total Cost: ${total_cost:.2f}</p>
            <p>Tagged Resources: {tagged_resources} ({tagged_resources_percent}%) | Tagged Cost: ${tagged_cost:.2f} ({tagged_cost_percent}%)</p>
            <p>Untagged Resources: {untagged_resources} ({100-tagged_resources_percent:.2f}%) | Untagged Cost: ${untagged_cost:.2f} ({100-tagged_cost_percent:.2f}%)</p>
            <p class="warning">Note: {untagged_resources} resources costing ${untagged_cost:.2f} are missing tags!</p>
        </div>
    """
    
    html_body += """
        <h3>Tagging Details by Service</h3>
        <table>
            <tr>
                <th>Service</th>
                <th>Total Resources</th>
                <th>Total Cost ($)</th>
                <th>Tagged Resources</th>
                <th>Tagged %</th>
                <th>Tagged Cost ($)</th>
                <th>Tagged Cost %</th>
                <th>Untagged Resources</th>
                <th>Untagged %</th>
                <th>Untagged Cost ($)</th>
                <th>Untagged Cost %</th>
            </tr>
    """
    
    # Add rows for tagged vs untagged services
    for item in tagged_vs_untagged_results:
        html_body += f"""
            <tr>
                <td>{item.get('service', 'N/A')}</td>
                <td>{item.get('total_resources', 'N/A')}</td>
                <td>{float(item.get('total_cost', 0)):.2f}</td>
                <td>{item.get('tagged_resources', 'N/A')}</td>
                <td>{item.get('tagged_resources_percent', 'N/A')}%</td>
                <td>{float(item.get('tagged_cost', 0)):.2f}</td>
                <td>{item.get('tagged_cost_percent', 'N/A')}%</td>
                <td>{item.get('untagged_resources', 'N/A')}</td>
                <td>{item.get('untagged_resources_percent', 'N/A')}%</td>
                <td>{float(item.get('untagged_cost', 0)):.2f}</td>
                <td>{item.get('untagged_cost_percent', 'N/A')}%</td>
            </tr>
        """
    
    # Add expensive untagged resources section
    html_body += """
        </table>
        
        <h2>2. Most Expensive Untagged Resources</h2>
        <table>
            <tr>
                <th>Service</th>
                <th>Resource ID</th>
                <th>Product Name</th>
                <th>Region</th>
                <th>Usage Type</th>
                <th>Cost ($)</th>
            </tr>
    """
    
    # Add rows for expensive untagged resources
    for item in expensive_untagged_results:
        html_body += f"""
            <tr>
                <td>{item.get('service', 'N/A')}</td>
                <td>{item.get('resource_id', 'N/A')}</td>
                <td>{item.get('product_name', 'N/A')}</td>
                <td>{item.get('region', 'N/A')}</td>
                <td>{item.get('usage_type', 'N/A')}</td>
                <td>{float(item.get('cost', 0)):.2f}</td>
            </tr>
        """
    html_body += "</table>"
    
    html_body += """
        <p>This report was automatically generated. Please do not reply to this email.</p>
    </body>
    </html>
    """
    
    # Attach HTML part
    part = MIMEText(html_body, 'html')
    msg.attach(part)
    
    # Generate CSV attachments
    csv_attachments = [
        ('tagged_vs_untagged.csv', tagged_vs_untagged_results),
        ('expensive_untagged.csv', expensive_untagged_results)
    ]
    
    for filename, data in csv_attachments:
        if not data:
            continue
            
        # Create CSV content using the csv module
        output = io.StringIO()
        if data:
            fieldnames = data[0].keys()
            writer = csv.DictWriter(output, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(data)
            
        # Attach CSV
        attachment = MIMEApplication(output.getvalue().encode('utf-8'))
        attachment['Content-Disposition'] = f'attachment; filename="{filename}"'
        msg.attach(attachment)
    
    # Send email
    response = ses_client.send_raw_email(
        Source=SENDER_EMAIL,
        Destinations=RECIPIENT_EMAILS,
        RawMessage={'Data': msg.as_string()}
    )
    
    print(f"Email sent! Message ID: {response['MessageId']}")
    return response

if __name__ == "__main__":
    # For local testing
    lambda_handler({}, None) 