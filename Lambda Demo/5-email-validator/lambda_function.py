import json
import re

def lambda_handler(event, context):
    """
    Email Validator
    Checks if an email address is valid
    """
    
    try:
        body = json.loads(event.get('body', '{}'))
        email = body.get('email', '')
        
        # Email validation regex
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        
        is_valid = bool(re.match(email_pattern, email))
        
        # Additional checks
        checks = {
            'has_at_symbol': '@' in email,
            'has_domain': '.' in email.split('@')[-1] if '@' in email else False,
            'length_ok': 5 <= len(email) <= 254,
            'no_spaces': ' ' not in email
        }
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'email': email,
                'is_valid': is_valid,
                'checks': checks,
                'message': 'Valid email address' if is_valid else 'Invalid email address'
            })
        }
    
    except Exception as e:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': str(e)})
        }
