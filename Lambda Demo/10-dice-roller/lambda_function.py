import json
import random

def lambda_handler(event, context):
    """
    Dice Roller
    Simulates rolling dice for games
    """
    
    try:
        body = json.loads(event.get('body', '{}'))
        
        num_dice = int(body.get('num_dice', 1))
        num_sides = int(body.get('num_sides', 6))
        
        # Validate input
        if num_dice < 1 or num_dice > 100:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Number of dice must be between 1 and 100'})
            }
        
        if num_sides < 2 or num_sides > 100:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Number of sides must be between 2 and 100'})
            }
        
        # Roll the dice
        rolls = [random.randint(1, num_sides) for _ in range(num_dice)]
        total = sum(rolls)
        average = total / num_dice
        
        # Statistics
        stats = {
            'min': min(rolls),
            'max': max(rolls),
            'average': round(average, 2),
            'total': total
        }
        
        # Check for special rolls
        special = []
        if len(set(rolls)) == 1:
            special.append(f'All {rolls[0]}s!')
        if num_sides == 6 and 6 in rolls:
            special.append(f'{rolls.count(6)} six(es)!')
        if num_sides == 20 and 20 in rolls:
            special.append('Natural 20! Critical hit!')
        if num_sides == 20 and 1 in rolls:
            special.append('Natural 1! Critical fail!')
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'dice': f'{num_dice}d{num_sides}',
                'rolls': rolls,
                'statistics': stats,
                'special': special if special else None
            })
        }
    
    except ValueError:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Invalid input. num_dice and num_sides must be integers.'})
        }
    except Exception as e:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': str(e)})
        }
