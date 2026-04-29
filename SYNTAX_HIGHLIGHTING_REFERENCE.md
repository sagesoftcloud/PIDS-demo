# Syntax Highlighting Reference

This document shows all the syntax highlighting used in the demo files for GitHub.

## ECS Demo

### Bash/Shell Commands
````markdown
```bash
docker build -t ecs-demo .
aws ecr get-login-password --region us-east-1
```
````

### Dockerfile
````markdown
```dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```
````

### HTML
````markdown
```html
<!DOCTYPE html>
<html>
<head>
    <title>ECS Demo</title>
</head>
<body>
    <h1>Hello World</h1>
</body>
</html>
```
````

---

## Lambda Demo

### Python Code
````markdown
```python
import json

def lambda_handler(event, context):
    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Hello'})
    }
```
````

### JSON Test Events
````markdown
```json
{
  "name": "John",
  "message": "Testing Lambda"
}
```
````

---

## Auto Scaling Demo

### Bash Scripts
````markdown
```bash
#!/bin/bash
./scripts/setup.sh
./scripts/stress-test.sh
```
````

### YAML (CloudFormation)
````markdown
```yaml
AWSTemplateFormatVersion: '2010-09-09'
Resources:
  MyBucket:
    Type: AWS::S3::Bucket
```
````

---

## Common Language Tags

| Language | Tag | Use For |
|----------|-----|---------|
| Bash/Shell | `bash` or `sh` | AWS CLI commands, shell scripts |
| Python | `python` | Lambda functions, scripts |
| JSON | `json` | Test events, API responses |
| YAML | `yaml` | CloudFormation, config files |
| Dockerfile | `dockerfile` | Docker container definitions |
| HTML | `html` | Web pages |
| CSS | `css` | Stylesheets |
| JavaScript | `javascript` or `js` | Frontend code |
| SQL | `sql` | Database queries |

---

## How to Use

1. Start code block with triple backticks and language name
2. Add your code
3. End with triple backticks

**Example:**
````
```python
print("Hello World")
```
````

**Result on GitHub:**
```python
print("Hello World")
```

---

## Benefits

✅ **Syntax Highlighting** - Code is colored and easier to read
✅ **Copy Button** - GitHub adds a copy button automatically
✅ **Better Readability** - Proper formatting for different languages
✅ **Professional Look** - Makes documentation look polished

---

## Current Status

### ECS Demo
- ✅ Bash commands highlighted
- ✅ Dockerfile syntax
- ✅ HTML code blocks

### Lambda Demo
- ✅ Python functions highlighted
- ✅ JSON test events
- ✅ All 10 examples properly formatted

### Auto Scaling Demo
- ✅ Bash scripts
- ✅ Configuration examples

**All demos now have proper syntax highlighting for GitHub!** 🎨
