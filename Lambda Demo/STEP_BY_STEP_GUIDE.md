# AWS Lambda - Step-by-Step Guide for Beginners

Welcome! This guide will help you create your first AWS Lambda functions. No prior experience needed!

**Time Required:** 30-45 minutes  
**Cost:** FREE (within AWS Free Tier)  
**Difficulty:** Beginner-friendly

---

## What is AWS Lambda?

AWS Lambda lets you run code without managing servers. You just upload your code, and AWS runs it for you. You only pay when your code runs!

**Think of it like:** Ordering food delivery instead of cooking - you get what you need without doing all the work.

---

## Before You Start

### What You Need:
- AWS Account credentials (provided by instructor)
- Web browser
- 30-45 minutes of time

### What You'll Build:
- 3 different Lambda functions
- Learn how to test and monitor them
- Understand when to use Lambda

---

## Function 1: Hello World Lambda (15 minutes)

### Step 1: Sign In to AWS Console

1. Go to https://console.aws.amazon.com
2. Sign in with your credentials
3. Make sure you're in **US East (N. Virginia)** region (top-right corner)

### Step 2: Open Lambda Service

1. Click the **search bar** at the top
2. Type **Lambda**
3. Click **Lambda** from the results

### Step 3: Create Your First Function

1. Click **Create function** (orange button)
2. Select **Author from scratch**
3. Fill in the details:
   - **Function name:** `hello-world-yourname` (replace yourname with your actual name)
   - **Runtime:** Select **Python 3.11**
   - **Architecture:** Leave as **x86_64**
4. Click **Create function** (bottom right)

**Wait 5-10 seconds** for AWS to create your function.

### Step 4: Add Your Code

1. Scroll down to the **Code source** section
2. You'll see a file called `lambda_function.py`
3. **Delete all the existing code**
4. Copy and paste this code:

```python
import json

def lambda_handler(event, context):
    """
    Basic Hello World Lambda function
    Returns a simple greeting message
    """
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Hello from Lambda!',
            'yourName': 'Replace with your name',
            'event': event
        })
    }
```

5. Click **Deploy** (orange button above the code)
6. Wait for the message: "Successfully updated the function"

### Step 5: Test Your Function

1. Click the **Test** tab (next to Code)
2. Click **Create new event**
3. Fill in:
   - **Event name:** `test1`
   - Leave the JSON as is (or replace with):
   ```json
   {
     "name": "John",
     "message": "Testing my first Lambda!"
   }
   ```
4. Click **Save**
5. Click **Test** (orange button)

**You should see:**
- Green box with "Execution result: succeeded"
- Your response with "Hello from Lambda!"
- Execution time and memory used

**Congratulations!** You just ran your first Lambda function! 🎉

---

## Function 2: S3 File Processor (15 minutes)

This function automatically runs when you upload a file to S3.

### Step 1: Create the Function

1. Go back to Lambda console (click **Lambda** in the top-left breadcrumb)
2. Click **Create function**
3. Fill in:
   - **Function name:** `s3-processor-yourname`
   - **Runtime:** **Python 3.11**
4. Click **Create function**

### Step 2: Add the Code

1. In the **Code source** section, delete existing code
2. Paste this code:

```python
import json
from datetime import datetime

def lambda_handler(event, context):
    """
    S3 Event Processor Lambda function
    Triggered when a file is uploaded to S3
    """
    
    print("=== S3 Event Received ===")
    
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
```

3. Click **Deploy**

### Step 3: Test with Sample S3 Event

1. Click the **Test** tab
2. Click **Create new event**
3. Fill in:
   - **Event name:** `s3-test`
   - **Template:** Select **s3-put** from the dropdown
4. Click **Save**
5. Click **Test**

**You should see:**
- Logs showing the file details
- Success message

**What just happened?** Your function processed a fake S3 upload event!

---

## Function 3: Simple Calculator API (15 minutes)

This function can be called from a web browser or app.

### Step 1: Create the Function

1. Go back to Lambda console
2. Click **Create function**
3. Fill in:
   - **Function name:** `calculator-api-yourname`
   - **Runtime:** **Python 3.11**
4. Click **Create function**

### Step 2: Add the Code

1. Delete existing code
2. Paste this code:

```python
import json

def lambda_handler(event, context):
    """
    Simple Calculator API
    Performs basic math operations
    """
    
    try:
        # Get parameters from the request
        body = json.loads(event.get('body', '{}'))
        
        num1 = float(body.get('num1', 0))
        num2 = float(body.get('num2', 0))
        operation = body.get('operation', 'add')
        
        # Perform calculation
        if operation == 'add':
            result = num1 + num2
        elif operation == 'subtract':
            result = num1 - num2
        elif operation == 'multiply':
            result = num1 * num2
        elif operation == 'divide':
            if num2 == 0:
                return {
                    'statusCode': 400,
                    'body': json.dumps({'error': 'Cannot divide by zero'})
                }
            result = num1 / num2
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Invalid operation'})
            }
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'num1': num1,
                'num2': num2,
                'operation': operation,
                'result': result
            })
        }
    
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
```

3. Click **Deploy**

### Step 3: Test the Calculator

1. Click the **Test** tab
2. Click **Create new event**
3. Fill in:
   - **Event name:** `calc-test`
   - Replace the JSON with:
   ```json
   {
     "body": "{\"num1\": 10, \"num2\": 5, \"operation\": \"add\"}"
   }
   ```
4. Click **Save**
5. Click **Test**

**You should see:**
- Result: 15 (10 + 5)

**Try different operations:**
- Change `"add"` to `"subtract"`, `"multiply"`, or `"divide"`
- Change the numbers
- Test again!

---

## Understanding Your Lambda Functions

### What You Just Created:

1. **Hello World** - Basic function that returns a message
2. **S3 Processor** - Automatically runs when files are uploaded
3. **Calculator API** - Performs calculations when called

### Key Concepts:

**Function Name:** Unique identifier for your function

**Runtime:** Programming language (we used Python 3.11)

**Handler:** The function that runs (lambda_handler)

**Event:** Input data sent to your function

**Response:** Output data returned by your function

---

## Viewing Logs (5 minutes)

See what your function is doing behind the scenes!

### Step 1: Open CloudWatch Logs

1. Go to any of your Lambda functions
2. Click the **Monitor** tab
3. Click **View CloudWatch logs**

### Step 2: View Log Streams

1. Click on the latest **Log stream** (top of the list)
2. You'll see:
   - START: Function started
   - Your print statements
   - END: Function finished
   - REPORT: Performance metrics

**What to look for:**
- **Duration:** How long it ran (milliseconds)
- **Memory Used:** How much memory it needed
- **Errors:** Any problems that occurred

---

## Understanding Costs

### AWS Free Tier (First 12 months):
- **1 million requests per month** - FREE
- **400,000 GB-seconds of compute time** - FREE

### What does this mean?
If your function runs for 1 second with 128 MB memory:
- You can run it **3.2 million times per month** for FREE!

### After Free Tier:
- **$0.20 per 1 million requests**
- **$0.0000166667 per GB-second**

**Example:** 100,000 requests = $0.02 (2 cents!)

---

## Common Use Cases

### When to Use Lambda:

✅ **Process uploaded files** (resize images, convert videos)
✅ **Build APIs** (mobile app backends, web services)
✅ **Scheduled tasks** (daily reports, cleanup jobs)
✅ **Real-time data processing** (IoT sensors, log analysis)
✅ **Chatbots** (Slack bots, customer service)

### When NOT to Use Lambda:

❌ Long-running tasks (max 15 minutes)
❌ Applications that need to run 24/7
❌ Tasks requiring large amounts of memory (max 10 GB)

---

## Challenge: Modify Your Functions!

Try these modifications to learn more:

### Challenge 1: Personalize Hello World
Change the message to include your name and favorite color.

### Challenge 2: Add More Math Operations
Add `power` and `modulo` operations to the calculator.

### Challenge 3: Enhanced S3 Processor
Make it check if the file is an image (ends with .jpg, .png, .gif).

---

## Cleanup (5 minutes)

**Important:** Delete your functions to keep your account clean.

### Delete Each Function:

1. Go to **Lambda** console
2. Select a function (check the box)
3. Click **Actions** → **Delete**
4. Type `delete` to confirm
5. Click **Delete**
6. Repeat for all 3 functions

**Verify:** Go to Lambda console and confirm no functions are listed.

---

## Troubleshooting

### Function Won't Deploy?
- Check for syntax errors in your code
- Make sure you clicked **Deploy** after pasting code

### Test Failed?
- Check the error message in the response
- Look at CloudWatch logs for details
- Verify your test event JSON is valid

### Can't Find Lambda Service?
- Use the search bar at the top
- Make sure you're signed in to AWS Console

---

## What You Learned

✅ How to create Lambda functions
✅ How to write Python code for Lambda
✅ How to test functions with different events
✅ How to view logs in CloudWatch
✅ When to use Lambda vs other services
✅ How Lambda pricing works

---

## Next Steps

1. **Try AWS SAM** - Deploy Lambda functions with infrastructure as code
2. **Add API Gateway** - Make your calculator accessible via HTTP
3. **Connect to S3** - Actually trigger your function with real file uploads
4. **Use DynamoDB** - Store and retrieve data
5. **Build a Project** - Create a real application using Lambda

---

## Resources

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [Lambda Free Tier](https://aws.amazon.com/lambda/pricing/)
- [Python for Lambda](https://docs.aws.amazon.com/lambda/latest/dg/lambda-python.html)

---

## Congratulations! 🎉

You've successfully created and tested 3 AWS Lambda functions!

You now understand:
- Serverless computing basics
- How to write Lambda functions
- How to test and monitor them
- When to use Lambda in real projects

**Keep learning and building!** 🚀
