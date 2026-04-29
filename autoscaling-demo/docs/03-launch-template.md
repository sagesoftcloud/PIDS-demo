# Step 3: Create Launch Template

Create a launch template that defines the configuration for EC2 instances in the Auto Scaling Group.

## Overview

A launch template specifies:
- AMI (Amazon Machine Image)
- Instance type
- Security groups
- User data (startup script)
- IAM instance profile
- Storage configuration

## Why Launch Templates?

Launch templates are preferred over launch configurations because they:
- Support versioning
- Allow multiple instance types
- Enable mixed instance policies
- Support newer EC2 features

## Step-by-Step Instructions

### 1. Load Configuration

```bash
source ~/asg-demo-config.sh
```

### 2. Get Latest Amazon Linux 2 AMI

```bash
# Get the latest Amazon Linux 2 AMI ID
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
            "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text \
  --region $AWS_REGION)

echo "AMI ID: $AMI_ID"
```

### 3. Create IAM Role for EC2 Instances

The instances need permissions to send metrics to CloudWatch.

```bash
# Create trust policy
cat > /tmp/ec2-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
  --role-name asg-demo-ec2-role \
  --assume-role-policy-document file:///tmp/ec2-trust-policy.json

# Attach CloudWatch policy
aws iam attach-role-policy \
  --role-name asg-demo-ec2-role \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

# Create instance profile
aws iam create-instance-profile \
  --instance-profile-name asg-demo-ec2-profile

# Add role to instance profile
aws iam add-role-to-instance-profile \
  --instance-profile-name asg-demo-ec2-profile \
  --role-name asg-demo-ec2-role

# Wait for instance profile to be ready
sleep 10

echo "IAM role and instance profile created"
```

### 4. Create SSH Key Pair (if you don't have one)

```bash
# Check if key pair exists
if ! aws ec2 describe-key-pairs --key-names asg-demo-key --region $AWS_REGION 2>/dev/null; then
  # Create new key pair
  aws ec2 create-key-pair \
    --key-name asg-demo-key \
    --region $AWS_REGION \
    --query 'KeyMaterial' \
    --output text > ~/.ssh/asg-demo-key.pem
  
  chmod 400 ~/.ssh/asg-demo-key.pem
  echo "Key pair created: ~/.ssh/asg-demo-key.pem"
else
  echo "Key pair 'asg-demo-key' already exists"
fi

export KEY_NAME=asg-demo-key
```

### 5. Prepare User Data Script

```bash
# Copy user data script to a temporary location
cp ../templates/user-data.sh /tmp/user-data.sh

# Base64 encode for launch template
USER_DATA=$(base64 -i /tmp/user-data.sh)
```

### 6. Create Launch Template

```bash
# Create launch template JSON
cat > /tmp/launch-template.json << EOF
{
  "LaunchTemplateName": "asg-demo-template",
  "VersionDescription": "Initial version",
  "LaunchTemplateData": {
    "ImageId": "$AMI_ID",
    "InstanceType": "t3.micro",
    "KeyName": "$KEY_NAME",
    "SecurityGroupIds": ["$INSTANCE_SG_ID"],
    "IamInstanceProfile": {
      "Name": "asg-demo-ec2-profile"
    },
    "UserData": "$USER_DATA",
    "TagSpecifications": [
      {
        "ResourceType": "instance",
        "Tags": [
          {
            "Key": "Name",
            "Value": "asg-demo-instance"
          },
          {
            "Key": "Environment",
            "Value": "demo"
          }
        ]
      }
    ],
    "MetadataOptions": {
      "HttpTokens": "required",
      "HttpPutResponseHopLimit": 1
    },
    "Monitoring": {
      "Enabled": true
    }
  }
}
EOF

# Create the launch template
TEMPLATE_ID=$(aws ec2 create-launch-template \
  --cli-input-json file:///tmp/launch-template.json \
  --region $AWS_REGION \
  --query 'LaunchTemplate.LaunchTemplateId' \
  --output text)

echo "Launch Template ID: $TEMPLATE_ID"
```

### 7. Update Configuration

```bash
cat >> ~/asg-demo-config.sh << EOF
export AMI_ID=$AMI_ID
export KEY_NAME=$KEY_NAME
export TEMPLATE_ID=$TEMPLATE_ID
EOF

echo "Configuration updated"
```

## Launch Template Configuration Explained

### Instance Type: t3.micro
- **vCPUs:** 2
- **Memory:** 1 GiB
- **Cost:** ~$0.0104/hour
- **Burstable performance:** Good for variable workloads

### Monitoring: Enabled
- Detailed monitoring (1-minute intervals)
- Required for responsive auto scaling
- Additional cost: $0.14 per instance per month

### Metadata Options
- **IMDSv2 required:** Enhanced security
- **Hop limit:** 1 (prevents metadata access from containers)

### User Data Script
The script:
1. Installs Apache web server
2. Installs stress testing tool
3. Creates dynamic web page showing instance info
4. Sets up metrics endpoints
5. Configures stress test controls
6. Sends custom metrics to CloudWatch

## Verification

```bash
# Describe launch template
aws ec2 describe-launch-templates \
  --launch-template-ids $TEMPLATE_ID \
  --region $AWS_REGION

# Get launch template data
aws ec2 describe-launch-template-versions \
  --launch-template-id $TEMPLATE_ID \
  --region $AWS_REGION
```

## Testing the Launch Template

Launch a test instance to verify configuration:

```bash
# Launch test instance
TEST_INSTANCE_ID=$(aws ec2 run-instances \
  --launch-template LaunchTemplateId=$TEMPLATE_ID \
  --subnet-id $SUBNET1_ID \
  --region $AWS_REGION \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Test instance launched: $TEST_INSTANCE_ID"

# Wait for instance to be running
aws ec2 wait instance-running \
  --instance-ids $TEST_INSTANCE_ID \
  --region $AWS_REGION

# Get public IP
TEST_PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $TEST_INSTANCE_ID \
  --region $AWS_REGION \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "Test instance public IP: $TEST_PUBLIC_IP"
echo "Wait 2-3 minutes for user data script to complete"
echo "Then visit: http://$TEST_PUBLIC_IP"
```

### Verify the test instance:

```bash
# SSH to instance
ssh -i ~/.ssh/asg-demo-key.pem ec2-user@$TEST_PUBLIC_IP

# Check Apache status
sudo systemctl status httpd

# Check if stress is installed
which stress

# Exit SSH
exit
```

### Terminate test instance:

```bash
aws ec2 terminate-instances \
  --instance-ids $TEST_INSTANCE_ID \
  --region $AWS_REGION

echo "Test instance terminated"
```

## Advanced: Creating Multiple Versions

```bash
# Create new version with different instance type
aws ec2 create-launch-template-version \
  --launch-template-id $TEMPLATE_ID \
  --version-description "t3.small version" \
  --launch-template-data '{"InstanceType":"t3.small"}' \
  --region $AWS_REGION

# Set default version
aws ec2 modify-launch-template \
  --launch-template-id $TEMPLATE_ID \
  --default-version 2 \
  --region $AWS_REGION
```

## Troubleshooting

**Issue:** Launch template creation fails
- Verify AMI ID is valid in your region
- Check security group ID exists
- Ensure IAM instance profile is created

**Issue:** Instances fail to launch
- Check IAM role has correct permissions
- Verify user data script syntax
- Review EC2 instance logs in AWS Console

**Issue:** User data script doesn't execute
- Check `/var/log/cloud-init-output.log` on instance
- Verify script has correct shebang (`#!/bin/bash`)
- Ensure script has no syntax errors

## Next Steps

Proceed to [Step 4: Create Application Load Balancer](./04-load-balancer.md)
