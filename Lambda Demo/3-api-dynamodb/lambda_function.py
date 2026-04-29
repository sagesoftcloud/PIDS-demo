import json
import boto3
import os

dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    """
    API Gateway Lambda function
    Handles HTTP requests and performs CRUD operations on DynamoDB
    """
    
    table_name = os.environ.get('TABLE_NAME', 'MyTable')
    table = dynamodb.Table(table_name)
    
    http_method = event.get('httpMethod', 'GET')
    
    try:
        if http_method == 'GET':
            # Get item
            item_id = event['queryStringParameters'].get('id')
            response = table.get_item(Key={'id': item_id})
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps(response.get('Item', {}))
            }
        
        elif http_method == 'POST':
            # Create item
            body = json.loads(event['body'])
            table.put_item(Item=body)
            return {
                'statusCode': 201,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'message': 'Item created successfully'})
            }
        
        elif http_method == 'DELETE':
            # Delete item
            item_id = event['queryStringParameters'].get('id')
            table.delete_item(Key={'id': item_id})
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'message': 'Item deleted successfully'})
            }
        
        else:
            return {
                'statusCode': 405,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Method not allowed'})
            }
    
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': str(e)})
        }
