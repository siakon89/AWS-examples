"""
Helper module for request authentication
"""
import boto3
import json


secret_manager = boto3.client("secretsmanager", region_name='eu-central-1')
get_secret_value_response = secret_manager.get_secret_value(
    SecretId="tunisia_pydata_demo"
)


API_KEY = json.loads(get_secret_value_response['SecretString'])["token"]


def is_authorized(headers):
    """
    Verify that a request contains the correct API key
    """
    return headers.get("x-api-key", "") == API_KEY or headers.get("X-Api-Key", "") == API_KEY
