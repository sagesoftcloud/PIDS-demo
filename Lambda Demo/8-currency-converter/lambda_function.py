import json

def lambda_handler(event, context):
    """
    Currency Converter
    Converts between different currencies using fixed rates
    """
    
    # Exchange rates (relative to USD)
    exchange_rates = {
        'USD': 1.0,
        'EUR': 0.92,
        'GBP': 0.79,
        'JPY': 149.50,
        'PHP': 56.25,
        'SGD': 1.35,
        'AUD': 1.52,
        'CAD': 1.36,
        'CNY': 7.24,
        'INR': 83.12
    }
    
    try:
        body = json.loads(event.get('body', '{}'))
        
        amount = float(body.get('amount', 0))
        from_currency = body.get('from', 'USD').upper()
        to_currency = body.get('to', 'PHP').upper()
        
        # Validate currencies
        if from_currency not in exchange_rates:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': f'Invalid source currency: {from_currency}'})
            }
        
        if to_currency not in exchange_rates:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': f'Invalid target currency: {to_currency}'})
            }
        
        # Convert to USD first, then to target currency
        amount_in_usd = amount / exchange_rates[from_currency]
        converted_amount = amount_in_usd * exchange_rates[to_currency]
        
        # Calculate exchange rate
        rate = exchange_rates[to_currency] / exchange_rates[from_currency]
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'original': {
                    'amount': amount,
                    'currency': from_currency
                },
                'converted': {
                    'amount': round(converted_amount, 2),
                    'currency': to_currency
                },
                'exchange_rate': round(rate, 4),
                'formula': f'1 {from_currency} = {round(rate, 4)} {to_currency}',
                'available_currencies': list(exchange_rates.keys())
            })
        }
    
    except ValueError:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Invalid amount. Must be a number.'})
        }
    except Exception as e:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': str(e)})
        }
