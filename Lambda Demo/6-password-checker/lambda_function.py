import json
import hashlib
import secrets

def lambda_handler(event, context):
    """
    Password Strength Checker
    Analyzes password strength and provides recommendations
    """
    
    try:
        body = json.loads(event.get('body', '{}'))
        password = body.get('password', '')
        
        # Check password criteria
        length = len(password)
        has_upper = any(c.isupper() for c in password)
        has_lower = any(c.islower() for c in password)
        has_digit = any(c.isdigit() for c in password)
        has_special = any(c in '!@#$%^&*()_+-=[]{}|;:,.<>?' for c in password)
        
        # Calculate strength score
        score = 0
        if length >= 8: score += 1
        if length >= 12: score += 1
        if has_upper: score += 1
        if has_lower: score += 1
        if has_digit: score += 1
        if has_special: score += 1
        
        # Determine strength level
        if score <= 2:
            strength = 'Weak'
            color = 'red'
        elif score <= 4:
            strength = 'Medium'
            color = 'orange'
        else:
            strength = 'Strong'
            color = 'green'
        
        # Generate recommendations
        recommendations = []
        if length < 8:
            recommendations.append('Use at least 8 characters')
        if length < 12:
            recommendations.append('Consider using 12+ characters for better security')
        if not has_upper:
            recommendations.append('Add uppercase letters (A-Z)')
        if not has_lower:
            recommendations.append('Add lowercase letters (a-z)')
        if not has_digit:
            recommendations.append('Add numbers (0-9)')
        if not has_special:
            recommendations.append('Add special characters (!@#$%^&*)')
        
        # Generate a strong password suggestion
        suggested_password = secrets.token_urlsafe(16)
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'strength': strength,
                'score': f'{score}/6',
                'color': color,
                'criteria': {
                    'length': length,
                    'has_uppercase': has_upper,
                    'has_lowercase': has_lower,
                    'has_numbers': has_digit,
                    'has_special_chars': has_special
                },
                'recommendations': recommendations,
                'suggested_password': suggested_password
            })
        }
    
    except Exception as e:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': str(e)})
        }
