import json
import base64

def lambda_handler(event, context):
    """
    Text Encoder/Decoder
    Encodes and decodes text using various methods
    """
    
    try:
        body = json.loads(event.get('body', '{}'))
        
        text = body.get('text', '')
        operation = body.get('operation', 'encode')  # encode or decode
        method = body.get('method', 'base64')  # base64, reverse, rot13
        
        result = ''
        
        if method == 'base64':
            if operation == 'encode':
                result = base64.b64encode(text.encode()).decode()
            else:
                result = base64.b64decode(text.encode()).decode()
        
        elif method == 'reverse':
            result = text[::-1]
        
        elif method == 'rot13':
            result = text.translate(str.maketrans(
                'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz',
                'NOPQRSTUVWXYZABCDEFGHIJKLMnopqrstuvwxyzabcdefghijklm'
            ))
        
        elif method == 'uppercase':
            result = text.upper()
        
        elif method == 'lowercase':
            result = text.lower()
        
        elif method == 'title':
            result = text.title()
        
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Invalid method. Use: base64, reverse, rot13, uppercase, lowercase, title'})
            }
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'original': text,
                'result': result,
                'method': method,
                'operation': operation,
                'length': {
                    'original': len(text),
                    'result': len(result)
                }
            })
        }
    
    except Exception as e:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': str(e)})
        }
