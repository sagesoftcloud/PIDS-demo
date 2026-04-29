# AWS Lambda Demo Functions

This folder contains 3 basic Lambda function examples demonstrating different use cases.

## Functions Overview

### 1. Hello World (`1-hello-world`)
**Purpose:** Basic Lambda function that returns a greeting message

**Use Case:** 
- Learning Lambda basics
- Testing Lambda deployment
- Understanding event and context objects

**Trigger:** Manual invocation or API Gateway

**Runtime:** Python 3.x

**IAM Permissions Required:** None (basic Lambda execution role)

---

### 2. S3 Event Processor (`2-s3-event-processor`)
**Purpose:** Processes files uploaded to S3 bucket

**Use Case:**
- Automatically process files when uploaded to S3
- Log file metadata
- Trigger workflows based on S3 events

**Trigger:** S3 bucket event (ObjectCreated)

**Runtime:** Python 3.x

**IAM Permissions Required:**
- `s3:GetObject`
- `s3:ListBucket`
- `logs:CreateLogGroup`
- `logs:CreateLogStream`
- `logs:PutLogEvents`

---

### 3. API + DynamoDB (`3-api-dynamodb`)
**Purpose:** REST API backend with DynamoDB integration

**Use Case:**
- Build serverless REST APIs
- Perform CRUD operations on DynamoDB
- Handle HTTP requests (GET, POST, DELETE)

**Trigger:** API Gateway

**Runtime:** Python 3.x

**Environment Variables:**
- `TABLE_NAME`: DynamoDB table name (default: MyTable)

**IAM Permissions Required:**
- `dynamodb:GetItem`
- `dynamodb:PutItem`
- `dynamodb:DeleteItem`
- `logs:CreateLogGroup`
- `logs:CreateLogStream`
- `logs:PutLogEvents`

---

## Deployment Instructions

### Using AWS Console

1. Go to AWS Lambda Console
2. Click **Create function**
3. Choose **Author from scratch**
4. Enter function name (e.g., `my-hello-world`)
5. Select **Python 3.x** runtime
6. Click **Create function**
7. Copy the code from the respective `lambda_function.py` file
8. Paste into the Lambda code editor
9. Click **Deploy**
10. Configure triggers as needed

### Using AWS CLI

```bash
# Create function
aws lambda create-function \
  --function-name my-hello-world \
  --runtime python3.11 \
  --role arn:aws:iam::ACCOUNT_ID:role/lambda-execution-role \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://function.zip

# Update function code
aws lambda update-function-code \
  --function-name my-hello-world \
  --zip-file fileb://function.zip
```

---

## Testing

### Test Event for Hello World
```json
{
  "name": "John",
  "message": "Testing Lambda"
}
```

### Test Event for S3 Event Processor
```json
{
  "Records": [
    {
      "s3": {
        "bucket": {
          "name": "my-bucket"
        },
        "object": {
          "key": "test-file.txt",
          "size": 1024
        }
      }
    }
  ]
}
```

### Test Event for API + DynamoDB (GET)
```json
{
  "httpMethod": "GET",
  "queryStringParameters": {
    "id": "123"
  }
}
```

### Test Event for API + DynamoDB (POST)
```json
{
  "httpMethod": "POST",
  "body": "{\"id\": \"123\", \"name\": \"John Doe\", \"email\": \"john@example.com\"}"
}
```

---

## Best Practices

1. **Error Handling:** Always wrap code in try-except blocks
2. **Logging:** Use `print()` statements for CloudWatch logs
3. **Environment Variables:** Store configuration in environment variables
4. **Timeouts:** Set appropriate timeout values (default: 3 seconds)
5. **Memory:** Start with 128 MB and increase if needed
6. **IAM Roles:** Follow principle of least privilege
7. **Cold Starts:** Keep functions warm for production workloads

---

## Cost Considerations

- **Free Tier:** 1M requests/month + 400,000 GB-seconds compute time
- **Pricing:** $0.20 per 1M requests + $0.0000166667 per GB-second
- **Example:** 100K requests with 128 MB, 1s duration = ~$0.02/month

---

## Next Steps

1. Deploy each function to your AWS account
2. Test with sample events
3. Configure appropriate triggers
4. Monitor logs in CloudWatch
5. Optimize performance and costs
6. Add error handling and validation
7. Implement CI/CD pipeline

---

## Resources

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [Lambda Pricing](https://aws.amazon.com/lambda/pricing/)
