#!/bin/bash

# Auto Scaling Group Demo - Automated Setup Script
# This script automates the entire setup process

set -e

echo "=========================================="
echo "  AWS Auto Scaling Group Demo Setup"
echo "=========================================="
echo ""

# Check prerequisites
command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required but not installed. Aborting." >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required but not installed. Aborting." >&2; exit 1; }

# Configuration
export AWS_REGION=${AWS_REGION:-us-east-1}
export VPC_NAME=asg-demo-vpc
export VPC_CIDR=10.0.0.0/16
export ASG_NAME=asg-demo-group

echo "Region: $AWS_REGION"
echo ""

# Step 1: Create VPC
echo "[1/8] Creating VPC and networking..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME}]" \
  --region $AWS_REGION \
  --query 'Vpc.VpcId' \
  --output text)

aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames --region $AWS_REGION
echo "VPC created: $VPC_ID"

# Create Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=asg-demo-igw}]" \
  --region $AWS_REGION \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID --region $AWS_REGION
echo "Internet Gateway created: $IGW_ID"

# Get availability zones
AZ1=$(aws ec2 describe-availability-zones --region $AWS_REGION --query 'AvailabilityZones[0].ZoneName' --output text)
AZ2=$(aws ec2 describe-availability-zones --region $AWS_REGION --query 'AvailabilityZones[1].ZoneName' --output text)

# Create subnets
SUBNET1_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone $AZ1 \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=asg-demo-subnet-1}]" \
  --region $AWS_REGION \
  --query 'Subnet.SubnetId' \
  --output text)

SUBNET2_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 \
  --availability-zone $AZ2 \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=asg-demo-subnet-2}]" \
  --region $AWS_REGION \
  --query 'Subnet.SubnetId' \
  --output text)

aws ec2 modify-subnet-attribute --subnet-id $SUBNET1_ID --map-public-ip-on-launch --region $AWS_REGION
aws ec2 modify-subnet-attribute --subnet-id $SUBNET2_ID --map-public-ip-on-launch --region $AWS_REGION
echo "Subnets created: $SUBNET1_ID, $SUBNET2_ID"

# Create route table
RTB_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=asg-demo-rtb}]" \
  --region $AWS_REGION \
  --query 'RouteTable.RouteTableId' \
  --output text)

aws ec2 create-route --route-table-id $RTB_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $AWS_REGION
aws ec2 associate-route-table --subnet-id $SUBNET1_ID --route-table-id $RTB_ID --region $AWS_REGION > /dev/null
aws ec2 associate-route-table --subnet-id $SUBNET2_ID --route-table-id $RTB_ID --region $AWS_REGION > /dev/null
echo "Route table configured: $RTB_ID"

# Step 2: Create Security Groups
echo ""
echo "[2/8] Creating security groups..."

ALB_SG_ID=$(aws ec2 create-security-group \
  --group-name asg-demo-alb-sg \
  --description "Security group for Application Load Balancer" \
  --vpc-id $VPC_ID \
  --region $AWS_REGION \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress --group-id $ALB_SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $AWS_REGION
aws ec2 create-tags --resources $ALB_SG_ID --tags Key=Name,Value=asg-demo-alb-sg --region $AWS_REGION
echo "ALB security group created: $ALB_SG_ID"

INSTANCE_SG_ID=$(aws ec2 create-security-group \
  --group-name asg-demo-instance-sg \
  --description "Security group for Auto Scaling Group instances" \
  --vpc-id $VPC_ID \
  --region $AWS_REGION \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress --group-id $INSTANCE_SG_ID --protocol tcp --port 80 --source-group $ALB_SG_ID --region $AWS_REGION
MY_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress --group-id $INSTANCE_SG_ID --protocol tcp --port 22 --cidr ${MY_IP}/32 --region $AWS_REGION
aws ec2 create-tags --resources $INSTANCE_SG_ID --tags Key=Name,Value=asg-demo-instance-sg --region $AWS_REGION
echo "Instance security group created: $INSTANCE_SG_ID"

# Step 3: Create IAM Role
echo ""
echo "[3/8] Creating IAM role..."

cat > /tmp/ec2-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF

aws iam create-role --role-name asg-demo-ec2-role --assume-role-policy-document file:///tmp/ec2-trust-policy.json 2>/dev/null || echo "Role already exists"
aws iam attach-role-policy --role-name asg-demo-ec2-role --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy 2>/dev/null || true
aws iam create-instance-profile --instance-profile-name asg-demo-ec2-profile 2>/dev/null || echo "Instance profile already exists"
aws iam add-role-to-instance-profile --instance-profile-name asg-demo-ec2-profile --role-name asg-demo-ec2-role 2>/dev/null || true
sleep 10
echo "IAM role created"

# Step 4: Create Launch Template
echo ""
echo "[4/8] Creating launch template..."

AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text \
  --region $AWS_REGION)

# Create key pair if doesn't exist
if ! aws ec2 describe-key-pairs --key-names asg-demo-key --region $AWS_REGION 2>/dev/null; then
  aws ec2 create-key-pair --key-name asg-demo-key --region $AWS_REGION --query 'KeyMaterial' --output text > ~/.ssh/asg-demo-key.pem
  chmod 400 ~/.ssh/asg-demo-key.pem
  echo "Key pair created: ~/.ssh/asg-demo-key.pem"
fi

USER_DATA=$(base64 -i ../templates/user-data.sh)

cat > /tmp/launch-template.json << EOF
{
  "LaunchTemplateName": "asg-demo-template",
  "LaunchTemplateData": {
    "ImageId": "$AMI_ID",
    "InstanceType": "t3.micro",
    "KeyName": "asg-demo-key",
    "SecurityGroupIds": ["$INSTANCE_SG_ID"],
    "IamInstanceProfile": {"Name": "asg-demo-ec2-profile"},
    "UserData": "$USER_DATA",
    "Monitoring": {"Enabled": true}
  }
}
EOF

TEMPLATE_ID=$(aws ec2 create-launch-template \
  --cli-input-json file:///tmp/launch-template.json \
  --region $AWS_REGION \
  --query 'LaunchTemplate.LaunchTemplateId' \
  --output text)

echo "Launch template created: $TEMPLATE_ID"

# Step 5: Create Load Balancer
echo ""
echo "[5/8] Creating Application Load Balancer..."

TG_ARN=$(aws elbv2 create-target-group \
  --name asg-demo-tg \
  --protocol HTTP \
  --port 80 \
  --vpc-id $VPC_ID \
  --health-check-path /health.html \
  --region $AWS_REGION \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

echo "Target group created: $TG_ARN"

ALB_ARN=$(aws elbv2 create-load-balancer \
  --name asg-demo-alb \
  --subnets $SUBNET1_ID $SUBNET2_ID \
  --security-groups $ALB_SG_ID \
  --region $AWS_REGION \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns $ALB_ARN \
  --region $AWS_REGION \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

echo "ALB created: $ALB_DNS"

LISTENER_ARN=$(aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN \
  --region $AWS_REGION \
  --query 'Listeners[0].ListenerArn' \
  --output text)

echo "Waiting for ALB to become active..."
aws elbv2 wait load-balancer-available --load-balancer-arns $ALB_ARN --region $AWS_REGION

# Step 6: Create Auto Scaling Group
echo ""
echo "[6/8] Creating Auto Scaling Group..."

aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name $ASG_NAME \
  --launch-template LaunchTemplateId=$TEMPLATE_ID \
  --min-size 1 \
  --max-size 5 \
  --desired-capacity 2 \
  --health-check-type ELB \
  --health-check-grace-period 300 \
  --vpc-zone-identifier "$SUBNET1_ID,$SUBNET2_ID" \
  --target-group-arns $TG_ARN \
  --region $AWS_REGION

aws autoscaling enable-metrics-collection \
  --auto-scaling-group-name $ASG_NAME \
  --granularity "1Minute" \
  --region $AWS_REGION

echo "Auto Scaling Group created: $ASG_NAME"

# Step 7: Create Scaling Policy
echo ""
echo "[7/8] Creating scaling policy..."

cat > /tmp/target-tracking-policy.json << 'EOF'
{
  "TargetValue": 50.0,
  "PredefinedMetricSpecification": {
    "PredefinedMetricType": "ASGAverageCPUUtilization"
  }
}
EOF

aws autoscaling put-scaling-policy \
  --auto-scaling-group-name $ASG_NAME \
  --policy-name target-tracking-cpu-policy \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration file:///tmp/target-tracking-policy.json \
  --region $AWS_REGION > /dev/null

echo "Scaling policy created"

# Step 8: Save Configuration
echo ""
echo "[8/8] Saving configuration..."

cat > ~/asg-demo-config.sh << EOF
export AWS_REGION=$AWS_REGION
export VPC_ID=$VPC_ID
export IGW_ID=$IGW_ID
export SUBNET1_ID=$SUBNET1_ID
export SUBNET2_ID=$SUBNET2_ID
export RTB_ID=$RTB_ID
export ALB_SG_ID=$ALB_SG_ID
export INSTANCE_SG_ID=$INSTANCE_SG_ID
export AMI_ID=$AMI_ID
export TEMPLATE_ID=$TEMPLATE_ID
export TG_ARN=$TG_ARN
export ALB_ARN=$ALB_ARN
export ALB_DNS=$ALB_DNS
export LISTENER_ARN=$LISTENER_ARN
export ASG_NAME=$ASG_NAME
EOF

echo "Configuration saved to ~/asg-demo-config.sh"

# Wait for instances
echo ""
echo "Waiting for instances to become healthy (this may take 3-5 minutes)..."
sleep 60

DESIRED=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region $AWS_REGION \
  --query 'AutoScalingGroups[0].DesiredCapacity' \
  --output text)

while true; do
  HEALTHY=$(aws elbv2 describe-target-health \
    --target-group-arn $TG_ARN \
    --region $AWS_REGION \
    --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' \
    --output text)
  
  echo "Healthy instances: $HEALTHY / $DESIRED"
  
  if [ "$HEALTHY" -eq "$DESIRED" ]; then
    break
  fi
  
  sleep 15
done

echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "Your Auto Scaling Group is ready!"
echo ""
echo "Application URL: http://$ALB_DNS"
echo ""
echo "Next steps:"
echo "1. Visit the application URL in your browser"
echo "2. Run stress tests: ./scripts/stress-test.sh"
echo "3. Monitor scaling: ./scripts/monitor.sh"
echo "4. When done, cleanup: ./scripts/cleanup.sh"
echo ""
echo "Configuration loaded. Run: source ~/asg-demo-config.sh"
