# More Lambda Function Examples

This guide contains 7 additional Lambda function examples for different use cases.

---

## Function 4: Random Quote Generator

**Purpose:** Returns random inspirational quotes

**Test Event:**
```json
{}
```

**Expected Response:**
```json
{
  "quote": "The only way to do great work is to love what you do.",
  "author": "Steve Jobs",
  "timestamp": "abc-123-def"
}
```

**Use Cases:**
- Daily motivation apps
- Website quote widgets
- Chatbot responses

---

## Function 5: Email Validator

**Purpose:** Validates email addresses and provides detailed checks

**Test Event:**
```json
{
  "body": "{\"email\": \"john.doe@example.com\"}"
}
```

**Expected Response:**
```json
{
  "email": "john.doe@example.com",
  "is_valid": true,
  "checks": {
    "has_at_symbol": true,
    "has_domain": true,
    "length_ok": true,
    "no_spaces": true
  },
  "message": "Valid email address"
}
```

**Try These:**
- Valid: `user@domain.com`
- Invalid: `invalid.email`
- Invalid: `user @domain.com` (has space)

---

## Function 6: Password Strength Checker

**Purpose:** Analyzes password strength and provides recommendations

**Test Event:**
```json
{
  "body": "{\"password\": \"MyP@ssw0rd123\"}"
}
```

**Expected Response:**
```json
{
  "strength": "Strong",
  "score": "6/6",
  "color": "green",
  "criteria": {
    "length": 13,
    "has_uppercase": true,
    "has_lowercase": true,
    "has_numbers": true,
    "has_special_chars": true
  },
  "recommendations": [],
  "suggested_password": "xK9mP2nQ7vL4wR8t"
}
```

**Try These:**
- Weak: `password`
- Medium: `Password123`
- Strong: `MyP@ssw0rd123!`

---

## Function 7: Age Calculator

**Purpose:** Calculates age from birthdate with fun facts

**Test Event:**
```json
{
  "body": "{\"birthdate\": \"1990-05-15\"}"
}
```

**Expected Response:**
```json
{
  "birthdate": "1990-05-15",
  "age": {
    "years": 33,
    "months": 405,
    "weeks": 1768,
    "days": 12380
  },
  "next_birthday": {
    "date": "2024-05-15",
    "days_until": 95
  },
  "zodiac_sign": "Taurus",
  "fun_facts": [
    "You've lived for 12,380 days!",
    "That's 1,768 weeks!",
    "Or 297,120 hours!"
  ]
}
```

**Try Your Own:**
- Replace `1990-05-15` with your birthdate
- Format must be `YYYY-MM-DD`

---

## Function 8: Currency Converter

**Purpose:** Converts between different currencies

**Test Event:**
```json
{
  "body": "{\"amount\": 100, \"from\": \"USD\", \"to\": \"PHP\"}"
}
```

**Expected Response:**
```json
{
  "original": {
    "amount": 100,
    "currency": "USD"
  },
  "converted": {
    "amount": 5625.0,
    "currency": "PHP"
  },
  "exchange_rate": 56.25,
  "formula": "1 USD = 56.25 PHP",
  "available_currencies": ["USD", "EUR", "GBP", "JPY", "PHP", "SGD", "AUD", "CAD", "CNY", "INR"]
}
```

**Try These:**
- USD to PHP: `{"amount": 100, "from": "USD", "to": "PHP"}`
- EUR to JPY: `{"amount": 50, "from": "EUR", "to": "JPY"}`
- PHP to USD: `{"amount": 5000, "from": "PHP", "to": "USD"}`

---

## Function 9: Text Encoder/Decoder

**Purpose:** Encodes and decodes text using various methods

**Test Event (Base64 Encode):**
```json
{
  "body": "{\"text\": \"Hello World\", \"operation\": \"encode\", \"method\": \"base64\"}"
}
```

**Expected Response:**
```json
{
  "original": "Hello World",
  "result": "SGVsbG8gV29ybGQ=",
  "method": "base64",
  "operation": "encode",
  "length": {
    "original": 11,
    "result": 16
  }
}
```

**Available Methods:**
- `base64` - Base64 encoding/decoding
- `reverse` - Reverse the text
- `rot13` - ROT13 cipher
- `uppercase` - Convert to uppercase
- `lowercase` - Convert to lowercase
- `title` - Convert to title case

**Try These:**
```json
{"text": "Hello World", "method": "reverse"}
{"text": "Hello World", "method": "rot13"}
{"text": "hello world", "method": "uppercase"}
```

---

## Function 10: Dice Roller

**Purpose:** Simulates rolling dice for games

**Test Event:**
```json
{
  "body": "{\"num_dice\": 3, \"num_sides\": 6}"
}
```

**Expected Response:**
```json
{
  "dice": "3d6",
  "rolls": [4, 2, 6],
  "statistics": {
    "min": 2,
    "max": 6,
    "average": 4.0,
    "total": 12
  },
  "special": ["1 six(es)!"]
}
```

**Try These:**
- Standard dice: `{"num_dice": 2, "num_sides": 6}` (2d6)
- D&D d20: `{"num_dice": 1, "num_sides": 20}` (1d20)
- Multiple d20: `{"num_dice": 3, "num_sides": 20}` (3d20)
- Coin flip: `{"num_dice": 1, "num_sides": 2}` (1d2)

---

## Quick Deployment Guide

### For Each Function:

1. **Create Function**
   - Go to Lambda Console
   - Click **Create function**
   - Name: `[function-name]-yourname`
   - Runtime: **Python 3.11**
   - Click **Create function**

2. **Add Code**
   - Copy code from the respective folder
   - Paste into Lambda editor
   - Click **Deploy**

3. **Test**
   - Click **Test** tab
   - Create new event with the test JSON provided
   - Click **Test**
   - Verify the response

---

## Use Case Matrix

| Function | Best For | Difficulty | Real-World Use |
|----------|----------|------------|----------------|
| Quote Generator | APIs, Widgets | Easy | Daily motivation apps |
| Email Validator | Form Validation | Easy | User registration |
| Password Checker | Security | Medium | Account creation |
| Age Calculator | Fun Apps | Medium | Birthday reminders |
| Currency Converter | Finance | Medium | E-commerce sites |
| Text Encoder | Utilities | Easy | Data transformation |
| Dice Roller | Gaming | Easy | Online board games |

---

## Challenge Exercises

### Easy Challenges:
1. **Quote Generator:** Add 10 more quotes
2. **Dice Roller:** Add support for advantage/disadvantage (D&D)
3. **Text Encoder:** Add a new encoding method

### Medium Challenges:
1. **Email Validator:** Check for disposable email domains
2. **Password Checker:** Add common password blacklist
3. **Currency Converter:** Add real-time exchange rates (API)

### Hard Challenges:
1. **Age Calculator:** Add historical events from birth year
2. **Combine Functions:** Create a user registration system using email validator + password checker
3. **Add Database:** Store quotes/passwords in DynamoDB

---

## Common Patterns

### Input Validation
```python
if not email or len(email) < 5:
    return {
        'statusCode': 400,
        'body': json.dumps({'error': 'Invalid input'})
    }
```

### Error Handling
```python
try:
    # Your code here
except ValueError as e:
    return {'statusCode': 400, 'body': json.dumps({'error': str(e)})}
except Exception as e:
    return {'statusCode': 500, 'body': json.dumps({'error': 'Internal error'})}
```

### CORS Headers
```python
'headers': {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*'
}
```

---

## Testing Tips

1. **Start Simple:** Test with basic inputs first
2. **Test Edge Cases:** Empty strings, zero values, invalid data
3. **Check Errors:** Verify error messages are helpful
4. **View Logs:** Use CloudWatch to debug issues
5. **Iterate:** Improve based on test results

---

## Next Steps

1. Deploy all 7 functions
2. Test each one with different inputs
3. Try the challenge exercises
4. Combine multiple functions
5. Build a real application
6. Add API Gateway for HTTP access
7. Create a frontend web app

---

## Resources

- [Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [Python Lambda Tutorial](https://docs.aws.amazon.com/lambda/latest/dg/lambda-python.html)
- [API Gateway Integration](https://docs.aws.amazon.com/lambda/latest/dg/services-apigateway.html)

---

**Happy Coding!** 🚀
