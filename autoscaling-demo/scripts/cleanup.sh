#!/bin/bash

# Auto Scaling Group Demo - Cleanup Script
# This script removes all resources created by the demo

set -e

echo "=========================================="
echo "  AWS Auto Scaling Group Demo Cleanup"
echo "=========================================="
echo ""

if [ ! -f ~/asg-demo-config.sh ]; then
  echo "Error: Configuration file not found"
  echo "Cannot proceed with cleanup"
  exit 1
fi

source ~/asg-demo-config.sh

echo "This will delete all resources created by the demo:"
echo "- Auto Scaling Group: $ASG_NAME"
echo "- Application Load Balancer: $ALB_DNS"
echo "- Launch Template: $TEMPLATE_ID"
echo "- VPC and networking: $VPC_ID"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "Cleanup cancelled"
  exit 0
fi

echo ""
echo "Starting cleanup..."

# Step 1: Delete Auto Scaling Group
echo ""
echo "[1/10] Deleting Auto Scaling Group..."
if aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME --region $AWS_REGION 2>/dev/null | grep -q $ASG_NAME; then
  aws autoscaling delete-auto-scaling-group \
    --auto-scaling-group-name $ASG_NAME \
    --force-delete \
    --region $AWS_REGION
  
  echo "Waiting for instances to terminate..."
  sleep 30
  
  while true; do
    INSTANCES=$(aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names $ASG_NAME \
      --region $AWS_REGION \
      --query 'AutoScalingGroups[0].Instances' \
      --output text 2>/dev/null)
    
    if [ -z "$INSTANCES" ]; then
      break
    fi
    
    echo "Waiting for instances to terminate..."
    sleep 10
  done
  
  echo "Auto Scaling Group deleted"
else
  echo "Auto Scaling Group not found, skipping"
fi

# Step 2: Delete Load Balancer
echo ""
echo "[2/10] Deleting Application Load Balancer..."
if aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --region $AWS_REGION 2>/dev/null | grep -q $ALB_ARN; then
  aws elbv2 delete-load-balancer \
    --load-balancer-arn $ALB_ARN \
    --region $AWS_REGION
  
  echo "Waiting for ALB to be deleted..."
  aws elbv2 wait load-balancers-deleted --load-balancer-arns $ALB_ARN --region $AWS_REGION 2>/dev/null || true
  echo "Load Balancer deleted"
else
  echo "Load Balancer not found, skipping"
fi

# Step 3: Delete Target Group
echo ""
echo "[3/10] Deleting Target Group..."
if aws elbv2 describe-target-groups --target-group-arns $TG_ARN --region $AWS_REGION 2>/dev/null | grep -q $TG_ARN; then
  aws elbv2 delete-target-group \
    --target-group-arn $TG_ARN \
    --region $AWS_REGION
  echo "Target Group deleted"
else
  echo "Target Group not found, skipping"
fi

# Step 4: Delete Launch Template
echo ""
echo "[4/10] Deleting Launch Template..."
if aws ec2 describe-launch-templates --launch-template-ids $TEMPLATE_ID --region $AWS_REGION 2>/dev/null | grep -q $TEMPLATE_ID; then
  aws ec2 delete-launch-template \
    --launch-template-id $TEMPLATE_ID \
    --region $AWS_REGION
  echo "Launch Template deleted"
else
  echo "Launch Template not found, skipping"
fi

# Step 5: Delete Security Groups
echo ""
echo "[5/10] Deleting Security Groups..."
sleep 10  # Wait for ENIs to be released

if aws ec2 describe-security-groups --group-ids $INSTANCE_SG_ID --region $AWS_REGION 2>/dev/null | grep -q $INSTANCE_SG_ID; then
  aws ec2 delete-security-group \
    --group-id $INSTANCE_SG_ID \
    --region $AWS_REGION
  echo "Instance Security Group deleted"
fi

if aws ec2 describe-security-groups --group-ids $ALB_SG_ID --region $AWS_REGION 2>/dev/null | grep -q $ALB_SG_ID; then
  aws ec2 delete-security-group \
    --group-id $ALB_SG_ID \
    --region $AWS_REGION
  echo "ALB Security Group deleted"
fi

# Step 6: Delete Subnets
echo ""
echo "[6/10] Deleting Subnets..."
if aws ec2 describe-subnets --subnet-ids $SUBNET1_ID --region $AWS_REGION 2>/dev/null | grep -q $SUBNET1_ID; then
  aws ec2 delete-subnet --subnet-id $SUBNET1_ID --region $AWS_REGION
  echo "Subnet 1 deleted"
fi

if aws ec2 describe-subnets --subnet-ids $SUBNET2_ID --region $AWS_REGION 2>/dev/null | grep -q $SUBNET2_ID; then
  aws ec2 delete-subnet --subnet-id $SUBNET2_ID --region $AWS_REGION
  echo "Subnet 2 deleted"
fi

# Step 7: Delete Route Table
echo ""
echo "[7/10] Deleting Route Table..."
if aws ec2 describe-route-tables --route-table-ids $RTB_ID --region $AWS_REGION 2>/dev/null | grep -q $RTB_ID; then
  aws ec2 delete-route-table --route-table-id $RTB_ID --region $AWS_REGION
  echo "Route Table deleted"
fi

# Step 8: Detach and Delete Internet Gateway
echo ""
echo "[8/10] Deleting Internet Gateway..."
if aws ec2 describe-internet-gateways --internet-gateway-ids $IGW_ID --region $AWS_REGION 2>/dev/null | grep -q $IGW_ID; then
  aws ec2 detach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID \
    --region $AWS_REGION 2>/dev/null || true
  
  aws ec2 delete-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --region $AWS_REGION
  echo "Internet Gateway deleted"
fi

# Step 9: Delete VPC
echo ""
echo "[9/10] Deleting VPC..."
if aws ec2 describe-vpcs --vpc-ids $VPC_ID --region $AWS_REGION 2>/dev/null | grep -q $VPC_ID; then
  aws ec2 delete-vpc --vpc-id $VPC_ID --region $AWS_REGION
  echo "VPC deleted"
fi

# Step 10: Delete IAM Resources
echo ""
echo "[10/10] Deleting IAM Resources..."
aws iam remove-role-from-instance-profile \
  --instance-profile-name asg-demo-ec2-profile \
  --role-name asg-demo-ec2-role 2>/dev/null || true

aws iam delete-instance-profile \
  --instance-profile-name asg-demo-ec2-profile 2>/dev/null || true

aws iam detach-role-policy \
  --role-name asg-demo-ec2-role \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy 2>/dev/null || true

aws iam delete-role \
  --role-name asg-demo-ec2-role 2>/dev/null || true

echo "IAM Resources deleted"

# Delete CloudWatch alarms
echo ""
echo "Deleting CloudWatch alarms..."
aws cloudwatch delete-alarms \
  --alarm-names asg-demo-cpu-high asg-demo-cpu-low asg-demo-critical-cpu asg-demo-no-healthy-targets asg-demo-high-error-rate \
  --region $AWS_REGION 2>/dev/null || true

# Delete CloudWatch dashboard
echo "Deleting CloudWatch dashboard..."
aws cloudwatch delete-dashboards \
  --dashboard-names asg-demo-dashboard \
  --region $AWS_REGION 2>/dev/null || true

# Optional: Delete key pair
echo ""
read -p "Delete SSH key pair? (yes/no): " delete_key
if [ "$delete_key" = "yes" ]; then
  aws ec2 delete-key-pair --key-name asg-demo-key --region $AWS_REGION 2>/dev/null || true
  rm -f ~/.ssh/asg-demo-key.pem
  echo "Key pair deleted"
fi

# Delete configuration file
rm -f ~/asg-demo-config.sh

echo ""
echo "=========================================="
echo "  Cleanup Complete!"
echo "=========================================="
echo ""
echo "All demo resources have been deleted."
echo ""
echo "Note: CloudWatch metrics and logs may take up to 15 minutes to fully disappear."
echo "Check AWS Console to verify all resources are deleted."
