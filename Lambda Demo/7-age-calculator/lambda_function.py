import json
from datetime import datetime, timedelta

def lambda_handler(event, context):
    """
    Age Calculator
    Calculates age from birthdate and provides fun facts
    """
    
    try:
        body = json.loads(event.get('body', '{}'))
        birthdate_str = body.get('birthdate', '')  # Format: YYYY-MM-DD
        
        # Parse birthdate
        birthdate = datetime.strptime(birthdate_str, '%Y-%m-%d')
        today = datetime.now()
        
        # Calculate age
        age_years = today.year - birthdate.year
        if (today.month, today.day) < (birthdate.month, birthdate.day):
            age_years -= 1
        
        # Calculate exact age
        age_delta = today - birthdate
        age_days = age_delta.days
        age_months = age_years * 12 + (today.month - birthdate.month)
        age_weeks = age_days // 7
        age_hours = age_days * 24
        age_minutes = age_hours * 60
        
        # Calculate next birthday
        next_birthday = datetime(today.year, birthdate.month, birthdate.day)
        if next_birthday < today:
            next_birthday = datetime(today.year + 1, birthdate.month, birthdate.day)
        days_to_birthday = (next_birthday - today).days
        
        # Fun facts
        fun_facts = [
            f"You've lived for {age_days:,} days!",
            f"That's {age_weeks:,} weeks!",
            f"Or {age_hours:,} hours!",
            f"Or {age_minutes:,} minutes!",
            f"Your next birthday is in {days_to_birthday} days!"
        ]
        
        # Zodiac sign
        zodiac_signs = {
            (3, 21, 4, 19): 'Aries',
            (4, 20, 5, 20): 'Taurus',
            (5, 21, 6, 20): 'Gemini',
            (6, 21, 7, 22): 'Cancer',
            (7, 23, 8, 22): 'Leo',
            (8, 23, 9, 22): 'Virgo',
            (9, 23, 10, 22): 'Libra',
            (10, 23, 11, 21): 'Scorpio',
            (11, 22, 12, 21): 'Sagittarius',
            (12, 22, 1, 19): 'Capricorn',
            (1, 20, 2, 18): 'Aquarius',
            (2, 19, 3, 20): 'Pisces'
        }
        
        zodiac = 'Unknown'
        for (start_month, start_day, end_month, end_day), sign in zodiac_signs.items():
            if (birthdate.month == start_month and birthdate.day >= start_day) or \
               (birthdate.month == end_month and birthdate.day <= end_day):
                zodiac = sign
                break
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'birthdate': birthdate_str,
                'age': {
                    'years': age_years,
                    'months': age_months,
                    'weeks': age_weeks,
                    'days': age_days
                },
                'next_birthday': {
                    'date': next_birthday.strftime('%Y-%m-%d'),
                    'days_until': days_to_birthday
                },
                'zodiac_sign': zodiac,
                'fun_facts': fun_facts
            })
        }
    
    except ValueError:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Invalid date format. Use YYYY-MM-DD'})
        }
    except Exception as e:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': str(e)})
        }
