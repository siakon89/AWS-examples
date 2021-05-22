import json
from authorizer import is_authorized
import pickle
import xgboost
import numpy as np


def lambda_handler(event, context):
    """Sample pure Lambda function

    Parameters
    ----------
    event: dict, required
        API Gateway Lambda Proxy Input Format

        Event doc: https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html#api-gateway-simple-proxy-for-lambda-input-format

    context: object, required
        Lambda Context runtime methods and attributes

        Context doc: https://docs.aws.amazon.com/lambda/latest/dg/python-context-object.html

    Returns
    ------
    API Gateway Lambda Proxy Output Format: dict

        Return doc: https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html
    """
    print('Received event: ' + json.dumps(event, indent=2))

    print("Loading model...")
    model = pickle.load(open('iris_model.pkl', 'rb'))
    print("model loaded")

    if not is_authorized(event.get("headers", {})):
        return {
            "body": json.dumps({"message": "Invalid API key"}),
            "statusCode": 400,
            "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
        }
    data = np.array(json.loads(event["body"])["data"])
    input_data = xgboost.DMatrix(data)

    predictions_local = model.predict(input_data)
    result = np.round(predictions_local).tolist()

    print("Returning: {}".format(result))

    return {
        "statusCode": 200,
        "body": json.dumps({"result": result})
    }
