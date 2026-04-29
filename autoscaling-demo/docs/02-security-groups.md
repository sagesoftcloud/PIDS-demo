# Step 2: Security Groups

Create security groups for the Application Load Balancer and EC2 instances.

## Overview

We'll create two security groups:
1. **ALB Security Group**: Allows HTTP/HTTPS from internet
2. **Instance Security Group**: Allows traffic from ALB and SSH for management

## Security Best Practices

- Principle of least privilege
- Only open necessary ports
- Restrict SSH to your IP (not 0.0.0.0/0 in production)
- Use security group references instead of CIDR blocks

## Step-by-Step Instructions

### 1. Load Configuration

```bash
# Load saved configuration
source ~/asg-demo-config.sh
```

### 2. Create ALB Security Group

```bash
# Create security group for ALB
ALB_SG_ID=$(aws ec2 create-security-group \
  --group-name asg-demo-alb-sg \
  --description "Security group for Application Load Balancer" \
  --vpc-id $VPC_ID \
  --region $AWS_REGION \
  --query 'GroupId' \
  --output text)

echo "ALB Security Group ID: $ALB_SG_ID"

# Allow HTTP from anywhere
aws ec2 authorize-security-group-ingress \
  --group-id $ALB_SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --region $AWS_REGION

# Allow HTTPS from anywhere (optional)
aws ec2 authorize-security-group-ingress \
  --group-id $ALB_SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0 \
  --region $AWS_REGION

# Tag the security group
aws ec2 create-tags \
  --resources $ALB_SG_ID \
  --tags Key=Name,Value=asg-demo-alb-sg \
  --region $AWS_REGION
```

### 3. Create Instance Security Group

```bash
# Create security group for EC2 instances
INSTANCE_SG_ID=$(aws ec2 create-security-group \
  --group-name asg-demo-instance-sg \
  --description "Security group for Auto Scaling Group instances" \
  --vpc-id $VPC_ID \
  --region $AWS_REGION \
  --query 'GroupId' \
  --output text)

echo "Instance Security Group ID: $INSTANCE_SG_ID"

# Allow HTTP from ALB security group
aws ec2 authorize-security-group-ingress \
  --group-id $INSTANCE_SG_ID \
  --protocol tcp \
  --port 80 \
  --source-group $ALB_SG_ID \
  --region $AWS_REGION

# Get your current IP for SSH access
MY_IP=$(curl -s https://checkip.amazonaws.com)
echo "Your IP: $MY_IP"

# Allow SSH from your IP only
aws ec2 authorize-security-group-ingress \
  --group-id $INSTANCE_SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr ${MY_IP}/32 \
  --region $AWS_REGION

# Tag the security group
aws ec2 create-tags \
  --resources $INSTANCE_SG_ID \
  --tags Key=Name,Value=asg-demo-instance-sg \
  --region $AWS_REGION
```

### 4. Update Configuration File

```bash
# Append security group IDs to config
cat >> ~/asg-demo-config.sh << EOF
export ALB_SG_ID=$ALB_SG_ID
export INSTANCE_SG_ID=$INSTANCE_SG_ID
EOF

echo "Configuration updated"
```

## Security Group Rules Summary

### ALB Security Group
| Type | Protocol | Port | Source | Purpose |
|------|----------|------|--------|---------|
| Inbound | TCP | 80 | 0.0.0.0/0 | HTTP from internet |
| Inbound | TCP | 443 | 0.0.0.0/0 | HTTPS from internet |
| Outbound | All | All | 0.0.0.0/0 | Default outbound |

### Instance Security Group
| Type | Protocol | Port | Source | Purpose |
|------|----------|------|--------|---------|
| Inbound | TCP | 80 | ALB SG | HTTP from load balancer |
| Inbound | TCP | 22 | Your IP | SSH access |
| Outbound | All | All | 0.0.0.0/0 | Default outbound |

## Verification

```bash
# Describe ALB security group
aws ec2 describe-security-groups \
  --group-ids $ALB_SG_ID \
  --region $AWS_REGION

# Describe instance security group
aws ec2 describe-security-groups \
  --group-ids $INSTANCE_SG_ID \
  --region $AWS_REGION
```

## Advanced: Adding Additional Rules

### Allow HTTPS to instances (if using SSL termination on instances)

```bash
aws ec2 authorize-security-group-ingress \
  --group-id $INSTANCE_SG_ID \
  --protocol tcp \
  --port 443 \
  --source-group $ALB_SG_ID \
  --region $AWS_REGION
```

### Allow instances to communicate with each other

```bash
aws ec2 authorize-security-group-ingress \
  --group-id $INSTANCE_SG_ID \
  --protocol -1 \
  --source-group $INSTANCE_SG_ID \
  --region $AWS_REGION
```

### Restrict SSH to specific IP range

```bash
# Revoke existing SSH rule
aws ec2 revoke-security-group-ingress \
  --group-id $INSTANCE_SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr ${MY_IP}/32 \
  --region $AWS_REGION

# Add new rule with corporate IP range
aws ec2 authorize-security-group-ingress \
  --group-id $INSTANCE_SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 203.0.113.0/24 \
  --region $AWS_REGION
```

## Troubleshooting

**Issue:** Cannot SSH to instances
- Verify your IP hasn't changed: `curl https://checkip.amazonaws.com`
- Check security group rules: `aws ec2 describe-security-groups --group-ids $INSTANCE_SG_ID`
- Ensure instances have public IPs

**Issue:** ALB cannot reach instances
- Verify instance security group allows traffic from ALB security group
- Check that both security groups are in the same VPC

**Issue:** Cannot access ALB from browser
- Verify ALB security group allows port 80 from 0.0.0.0/0
- Check ALB is in "active" state
- Confirm DNS name resolves

## Next Steps

Proceed to [Step 3: Create Launch Template](./03-launch-template.md)
