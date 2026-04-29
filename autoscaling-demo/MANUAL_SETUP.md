# Manual Auto Scaling Setup - Step-by-Step Procedure

A practical, hands-on guide to manually set up AWS Auto Scaling with a sample website.

**Time Required:** 45-60 minutes  
**Cost:** ~$0.10 for 2-hour test

---

## Prerequisites

- AWS Account
- AWS CLI configured: `aws configure`
- SSH key pair or ability to create one
- Basic terminal knowledge

---

## Step 1: Set Variables (5 minutes)

Open terminal and set these variables:

```bash
export AWS_REGION=us-east-1
export PROJECT_NAME=myasg
```

---

## Step 2: Create VPC and Subnets (10 minutes)

### 2.1 Create VPC

```bash
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --region $AWS_REGION \
  --query 'Vpc.VpcId' \
  --output text)

echo "VPC ID: $VPC_ID"

aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-hostnames
```

### 2.2 Create Internet Gateway

```bash
IGW_ID=$(aws ec2 create-internet-gateway \
  --region $AWS_REGION \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

aws ec2 attach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID
```

### 2.3 Create Two Subnets (Different AZs)

```bash
SUBNET1_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone ${AWS_REGION}a \
  --query 'Subnet.SubnetId' \
  --output text)

SUBNET2_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 \
  --availability-zone ${AWS_REGION}b \
  --query 'Subnet.SubnetId' \
  --output text)

aws ec2 modify-subnet-attribute --subnet-id $SUBNET1_ID --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $SUBNET2_ID --map-public-ip-on-launch
```

### 2.4 Create Route Table

```bash
RTB_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --query 'RouteTable.RouteTableId' \
  --output text)

aws ec2 create-route \
  --route-table-id $RTB_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

aws ec2 associate-route-table --subnet-id $SUBNET1_ID --route-table-id $RTB_ID
aws ec2 associate-route-table --subnet-id $SUBNET2_ID --route-table-id $RTB_ID
```

---

## Step 3: Create Security Groups (5 minutes)

### 3.1 ALB Security Group

```bash
ALB_SG=$(aws ec2 create-security-group \
  --group-name ${PROJECT_NAME}-alb-sg \
  --description "ALB Security Group" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $ALB_SG \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0
```

### 3.2 Instance Security Group

```bash
INSTANCE_SG=$(aws ec2 create-security-group \
  --group-name ${PROJECT_NAME}-instance-sg \
  --description "Instance Security Group" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $INSTANCE_SG \
  --protocol tcp \
  --port 80 \
  --source-group $ALB_SG

MY_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress \
  --group-id $INSTANCE_SG \
  --protocol tcp \
  --port 22 \
  --cidr ${MY_IP}/32
```

---

## Step 4: Create Sample Website Script (5 minutes)

Create the user data script:

```bash
cat > /tmp/userdata.sh << 'EOF'
#!/bin/bash
yum update -y
yum install -y httpd

INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
AZ=$(ec2-metadata --availability-zone | cut -d " " -f 2)

cat > /var/www/html/index.html << HTML
<!DOCTYPE html>
<html>
<head>
    <title>Auto Scaling Demo</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            background: rgba(255, 255, 255, 0.1);
            padding: 30px;
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        .info {
            background: rgba(255, 255, 255, 0.2);
            padding: 15px;
            border-radius: 5px;
            margin: 10px 0;
        }
        h1 { margin-top: 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Auto Scaling Demo</h1>
        <div class="info">
            <strong>Instance ID:</strong> $INSTANCE_ID<br>
            <strong>Availability Zone:</strong> $AZ<br>
            <strong>Status:</strong> ✅ Running
        </div>
        <p>Refresh this page to see different instances serve your request!</p>
    </div>
</body>
</html>
HTML

systemctl start httpd
systemctl enable httpd
EOF
```

---

## Step 5: Create Launch Template (5 minutes)

### 5.1 Get Latest Amazon Linux 2 AMI

```bash
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
            "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text)

echo "AMI ID: $AMI_ID"
```

### 5.2 Create Key Pair (if needed)

```bash
aws ec2 create-key-pair \
  --key-name ${PROJECT_NAME}-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/${PROJECT_NAME}-key.pem

chmod 400 ~/.ssh/${PROJECT_NAME}-key.pem
```

### 5.3 Create Launch Template

```bash
aws ec2 create-launch-template \
  --launch-template-name ${PROJECT_NAME}-template \
  --launch-template-data "{
    \"ImageId\": \"$AMI_ID\",
    \"InstanceType\": \"t3.micro\",
    \"KeyName\": \"${PROJECT_NAME}-key\",
    \"SecurityGroupIds\": [\"$INSTANCE_SG\"],
    \"UserData\": \"$(base64 -i /tmp/userdata.sh)\",
    \"Monitoring\": {\"Enabled\": true}
  }"
```

---

## Step 6: Create Load Balancer (10 minutes)

### 6.1 Create Target Group

```bash
TG_ARN=$(aws elbv2 create-target-group \
  --name ${PROJECT_NAME}-tg \
  --protocol HTTP \
  --port 80 \
  --vpc-id $VPC_ID \
  --health-check-path / \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

echo "Target Group ARN: $TG_ARN"
```

### 6.2 Create Application Load Balancer

```bash
ALB_ARN=$(aws elbv2 create-load-balancer \
  --name ${PROJECT_NAME}-alb \
  --subnets $SUBNET1_ID $SUBNET2_ID \
  --security-groups $ALB_SG \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns $ALB_ARN \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

echo "ALB DNS: $ALB_DNS"
echo "Save this URL!"
```

### 6.3 Create Listener

```bash
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN
```

### 6.4 Wait for ALB to be Active

```bash
echo "Waiting for ALB to be active (2-3 minutes)..."
aws elbv2 wait load-balancer-available --load-balancer-arns $ALB_ARN
echo "ALB is ready!"
```

---

## Step 7: Create Auto Scaling Group (5 minutes)

```bash
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name ${PROJECT_NAME}-asg \
  --launch-template LaunchTemplateName=${PROJECT_NAME}-template \
  --min-size 1 \
  --max-size 4 \
  --desired-capacity 2 \
  --health-check-type ELB \
  --health-check-grace-period 300 \
  --vpc-zone-identifier "$SUBNET1_ID,$SUBNET2_ID" \
  --target-group-arns $TG_ARN

echo "Auto Scaling Group created!"
```

---

## Step 8: Create Scaling Policy (5 minutes)

```bash
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name ${PROJECT_NAME}-asg \
  --policy-name cpu-target-tracking \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration '{
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ASGAverageCPUUtilization"
    },
    "TargetValue": 50.0
  }'

echo "Scaling policy created - will maintain 50% CPU"
```

---

## Step 9: Wait and Verify (5 minutes)

### 9.1 Wait for Instances

```bash
echo "Waiting for instances to launch (3-5 minutes)..."
sleep 180

aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names ${PROJECT_NAME}-asg \
  --query 'AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus]' \
  --output table
```

### 9.2 Check Target Health

```bash
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
  --output table
```

### 9.3 Test Website

```bash
echo "Testing website..."
curl http://$ALB_DNS

echo ""
echo "Open in browser: http://$ALB_DNS"
```

---

## Step 10: Test Auto Scaling (10 minutes)

### 10.1 Install Stress Testing Tool

```bash
# macOS
brew install hey

# Linux
wget https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64
chmod +x hey_linux_amd64
sudo mv hey_linux_amd64 /usr/local/bin/hey
```

### 10.2 Generate Load

```bash
# Run load test (5 minutes, 100 concurrent requests)
hey -z 5m -c 100 http://$ALB_DNS
```

### 10.3 Monitor Scaling

In another terminal:

```bash
# Watch instances scale
watch -n 10 "aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names ${PROJECT_NAME}-asg \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]' \
  --output table"
```

### 10.4 View Scaling Activities

```bash
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name ${PROJECT_NAME}-asg \
  --max-records 10 \
  --query 'Activities[*].[StartTime,StatusCode,Description]' \
  --output table
```

---

## Step 11: Monitor with CloudWatch (Optional)

### View CPU Metrics

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=${PROJECT_NAME}-asg \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average \
  --query 'Datapoints | sort_by(@, &Timestamp)[-10:].[Timestamp,Average]' \
  --output table
```

---

## Step 12: Cleanup (5 minutes)

**Important:** Run this to avoid charges!

```bash
# Delete Auto Scaling Group
aws autoscaling delete-auto-scaling-group \
  --auto-scaling-group-name ${PROJECT_NAME}-asg \
  --force-delete

echo "Waiting for instances to terminate..."
sleep 60

# Delete Load Balancer
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN
sleep 30

# Delete Target Group
aws elbv2 delete-target-group --target-group-arn $TG_ARN

# Delete Launch Template
aws ec2 delete-launch-template --launch-template-name ${PROJECT_NAME}-template

# Delete Security Groups
sleep 30
aws ec2 delete-security-group --group-id $INSTANCE_SG
aws ec2 delete-security-group --group-id $ALB_SG

# Delete Subnets
aws ec2 delete-subnet --subnet-id $SUBNET1_ID
aws ec2 delete-subnet --subnet-id $SUBNET2_ID

# Delete Route Table
aws ec2 delete-route-table --route-table-id $RTB_ID

# Delete Internet Gateway
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID

# Delete VPC
aws ec2 delete-vpc --vpc-id $VPC_ID

echo "Cleanup complete!"
```

---

## Quick Reference Commands

### Check ASG Status
```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names ${PROJECT_NAME}-asg
```

### Manual Scale Out
```bash
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name ${PROJECT_NAME}-asg \
  --desired-capacity 3
```

### Manual Scale In
```bash
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name ${PROJECT_NAME}-asg \
  --desired-capacity 1
```

### View Recent Activities
```bash
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name ${PROJECT_NAME}-asg \
  --max-records 5
```

---

## Troubleshooting

### Instances not launching?
```bash
# Check ASG activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name ${PROJECT_NAME}-asg \
  --max-records 5
```

### Can't access website?
```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn $TG_ARN

# Verify ALB is active
aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN
```

### Scaling not working?
```bash
# Check CPU metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=${PROJECT_NAME}-asg \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average
```

---

## Summary

You've successfully created:
- ✅ VPC with 2 subnets across 2 AZs
- ✅ Application Load Balancer
- ✅ Auto Scaling Group (min: 1, max: 4, desired: 2)
- ✅ Target tracking scaling policy (50% CPU)
- ✅ Sample website showing instance info

**Your website:** http://$ALB_DNS

**Cost:** ~$0.10 for 2-hour test

**Remember:** Run cleanup commands when done!
