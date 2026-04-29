# Step 5: Create Auto Scaling Group

Create the Auto Scaling Group that automatically manages EC2 instance capacity.

## Overview

An Auto Scaling Group:
- Maintains desired number of instances
- Automatically replaces unhealthy instances
- Scales capacity based on demand
- Distributes instances across Availability Zones
- Integrates with load balancers

## Key Concepts

**Capacity Settings:**
- **Minimum:** Lowest number of instances (always running)
- **Desired:** Target number of instances
- **Maximum:** Highest number of instances (cost protection)

**Health Checks:**
- **EC2:** Instance status checks
- **ELB:** Load balancer health checks (more comprehensive)

## Step-by-Step Instructions

### 1. Load Configuration

```bash
source ~/asg-demo-config.sh
```

### 2. Create Auto Scaling Group

```bash
# Create Auto Scaling Group
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name asg-demo-group \
  --launch-template LaunchTemplateId=$TEMPLATE_ID,Version='$Latest' \
  --min-size 1 \
  --max-size 5 \
  --desired-capacity 2 \
  --default-cooldown 300 \
  --health-check-type ELB \
  --health-check-grace-period 300 \
  --vpc-zone-identifier "$SUBNET1_ID,$SUBNET2_ID" \
  --target-group-arns $TG_ARN \
  --termination-policies "OldestInstance" \
  --tags \
    Key=Name,Value=asg-demo-instance,PropagateAtLaunch=true \
    Key=Environment,Value=demo,PropagateAtLaunch=true \
  --region $AWS_REGION

echo "Auto Scaling Group created: asg-demo-group"

# Save ASG name
export ASG_NAME=asg-demo-group
cat >> ~/asg-demo-config.sh << EOF
export ASG_NAME=$ASG_NAME
EOF
```

### 3. Enable Metrics Collection

Enable detailed metrics for better monitoring:

```bash
aws autoscaling enable-metrics-collection \
  --auto-scaling-group-name $ASG_NAME \
  --granularity "1Minute" \
  --region $AWS_REGION

echo "Metrics collection enabled"
```

### 4. Wait for Instances to Launch

```bash
echo "Waiting for instances to launch and become healthy..."
echo "This may take 3-5 minutes..."

while true; do
  # Get instance count
  INSTANCE_COUNT=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $ASG_NAME \
    --region $AWS_REGION \
    --query 'AutoScalingGroups[0].Instances[?HealthStatus==`Healthy`]' \
    --output json | jq length)
  
  DESIRED=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $ASG_NAME \
    --region $AWS_REGION \
    --query 'AutoScalingGroups[0].DesiredCapacity' \
    --output text)
  
  echo "Healthy instances: $INSTANCE_COUNT / $DESIRED"
  
  if [ "$INSTANCE_COUNT" -eq "$DESIRED" ]; then
    echo "All instances are healthy!"
    break
  fi
  
  sleep 15
done
```

### 5. Verify Target Group Health

```bash
echo "Checking target group health..."

aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region $AWS_REGION \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
  --output table
```

### 6. Get Instance Information

```bash
# Get instance IDs and IPs
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region $AWS_REGION \
  --query 'AutoScalingGroups[0].Instances[*].[InstanceId,AvailabilityZone,HealthStatus]' \
  --output table

# Get public IPs
INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region $AWS_REGION \
  --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
  --output text)

echo ""
echo "Instance Public IPs:"
for INSTANCE_ID in $INSTANCE_IDS; do
  PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --region $AWS_REGION \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)
  echo "$INSTANCE_ID: $PUBLIC_IP"
done
```

## Auto Scaling Group Configuration Explained

### Capacity Settings
```
Min: 1    Desired: 2    Max: 5
```

- **Min (1):** Always keep at least 1 instance running
- **Desired (2):** Start with 2 instances for redundancy
- **Max (5):** Never exceed 5 instances (cost control)

### Health Check Configuration

**Type:** ELB (Elastic Load Balancer)
- More comprehensive than EC2 checks
- Checks application availability, not just instance status
- Automatically replaces instances that fail health checks

**Grace Period:** 300 seconds (5 minutes)
- Time to wait before checking instance health
- Allows user data script to complete
- Prevents premature termination

### Cooldown Period

**Default Cooldown:** 300 seconds (5 minutes)
- Wait time after scaling activity
- Prevents rapid scaling oscillations
- Allows metrics to stabilize

### Termination Policy

**OldestInstance:**
- Terminates oldest instance first
- Good for testing new configurations
- Ensures instances are regularly refreshed

**Other options:**
- `NewestInstance`: Terminate newest first
- `OldestLaunchTemplate`: Terminate instances with oldest template
- `Default`: AWS decides based on multiple factors

## Testing the Auto Scaling Group

### 1. Access Application via ALB

```bash
echo "Access your application at: http://$ALB_DNS"
echo ""
echo "Refresh multiple times to see different instances serving requests"
```

### 2. Test Instance Distribution

```bash
# Make multiple requests and see which instance responds
for i in {1..20}; do
  curl -s http://$ALB_DNS | grep -E "(Instance ID|Availability Zone)" | head -2
  echo "---"
  sleep 1
done
```

### 3. Test Auto-Healing

Terminate an instance and watch ASG replace it:

```bash
# Get first instance ID
INSTANCE_TO_TERMINATE=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region $AWS_REGION \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
  --output text)

echo "Terminating instance: $INSTANCE_TO_TERMINATE"

# Terminate instance
aws ec2 terminate-instances \
  --instance-ids $INSTANCE_TO_TERMINATE \
  --region $AWS_REGION

echo "Watch ASG launch a replacement instance..."

# Monitor ASG activity
watch -n 5 "aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region $AWS_REGION \
  --query 'AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus]' \
  --output table"
```

## Verification Commands

### Check ASG Status

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region $AWS_REGION
```

### View Scaling Activities

```bash
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $ASG_NAME \
  --max-records 10 \
  --region $AWS_REGION \
  --query 'Activities[*].[StartTime,StatusCode,Description]' \
  --output table
```

### Check Instance Health

```bash
# ASG perspective
aws autoscaling describe-auto-scaling-instances \
  --region $AWS_REGION \
  --query 'AutoScalingInstances[?AutoScalingGroupName==`'$ASG_NAME'`].[InstanceId,HealthStatus,LifecycleState]' \
  --output table

# Target group perspective
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region $AWS_REGION \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
  --output table
```

## Manual Scaling

### Scale Out (Add Instances)

```bash
# Increase desired capacity
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name $ASG_NAME \
  --desired-capacity 4 \
  --region $AWS_REGION

echo "Scaling out to 4 instances..."
```

### Scale In (Remove Instances)

```bash
# Decrease desired capacity
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name $ASG_NAME \
  --desired-capacity 2 \
  --region $AWS_REGION

echo "Scaling in to 2 instances..."
```

### Update Capacity Limits

```bash
# Update min/max capacity
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name $ASG_NAME \
  --min-size 2 \
  --max-size 10 \
  --region $AWS_REGION
```

## Advanced: Instance Protection

Protect specific instances from scale-in:

```bash
# Protect an instance
aws autoscaling set-instance-protection \
  --instance-ids $INSTANCE_ID \
  --auto-scaling-group-name $ASG_NAME \
  --protected-from-scale-in \
  --region $AWS_REGION

# Remove protection
aws autoscaling set-instance-protection \
  --instance-ids $INSTANCE_ID \
  --auto-scaling-group-name $ASG_NAME \
  --no-protected-from-scale-in \
  --region $AWS_REGION
```

## Advanced: Suspend/Resume Processes

Temporarily disable auto scaling:

```bash
# Suspend all processes
aws autoscaling suspend-processes \
  --auto-scaling-group-name $ASG_NAME \
  --region $AWS_REGION

# Suspend specific processes
aws autoscaling suspend-processes \
  --auto-scaling-group-name $ASG_NAME \
  --scaling-processes Launch Terminate \
  --region $AWS_REGION

# Resume processes
aws autoscaling resume-processes \
  --auto-scaling-group-name $ASG_NAME \
  --region $AWS_REGION
```

## Troubleshooting

**Issue:** Instances not launching
- Check launch template is valid
- Verify IAM instance profile exists
- Review Auto Scaling activity history
- Check subnet has available IPs

**Issue:** Instances launching but unhealthy
- Increase health check grace period
- Check user data script for errors
- Verify security groups allow ALB traffic
- Review instance system logs

**Issue:** Instances not registering with target group
- Verify target group ARN is correct
- Check instances are in correct subnets
- Ensure health check path is accessible

**Issue:** Scaling activities failing
- Check service limits (EC2 instance limit)
- Verify IAM permissions for Auto Scaling
- Review CloudWatch Logs for errors

## Next Steps

Proceed to [Step 6: Configure Scaling Policies](./06-scaling-policies.md)
