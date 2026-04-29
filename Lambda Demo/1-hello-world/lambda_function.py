import json

def lambda_handler(event, context):
    """
    Basic Hello World Lambda function
    Returns a simple greeting message
    """
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Hello from Lambda!',
            'event': event
        })
    }
