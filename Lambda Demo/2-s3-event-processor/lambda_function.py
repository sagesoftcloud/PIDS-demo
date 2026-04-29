import json
import boto3
from datetime import datetime

s3 = boto3.client('s3')

def lambda_handler(event, context):
    """
    S3 Event Processor Lambda function
    Triggered when a file is uploaded to S3
    Logs file details and metadata
    """
    
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        size = record['s3']['object']['size']
        
        print(f"File uploaded: {key}")
        print(f"Bucket: {bucket}")
        print(f"Size: {size} bytes")
        print(f"Timestamp: {datetime.now().isoformat()}")
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'S3 event processed successfully',
            'filesProcessed': len(event['Records'])
        })
    }
