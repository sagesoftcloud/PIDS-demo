import json
import random

def lambda_handler(event, context):
    """
    Random Quote Generator
    Returns a random inspirational quote
    """
    
    quotes = [
        {"quote": "The only way to do great work is to love what you do.", "author": "Steve Jobs"},
        {"quote": "Innovation distinguishes between a leader and a follower.", "author": "Steve Jobs"},
        {"quote": "Stay hungry, stay foolish.", "author": "Steve Jobs"},
        {"quote": "The future belongs to those who believe in the beauty of their dreams.", "author": "Eleanor Roosevelt"},
        {"quote": "It always seems impossible until it's done.", "author": "Nelson Mandela"},
        {"quote": "Don't watch the clock; do what it does. Keep going.", "author": "Sam Levenson"},
        {"quote": "The best time to plant a tree was 20 years ago. The second best time is now.", "author": "Chinese Proverb"},
        {"quote": "Your time is limited, don't waste it living someone else's life.", "author": "Steve Jobs"}
    ]
    
    selected_quote = random.choice(quotes)
    
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({
            'quote': selected_quote['quote'],
            'author': selected_quote['author'],
            'timestamp': context.request_id
        })
    }
