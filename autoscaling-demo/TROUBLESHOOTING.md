# Troubleshooting Guide

Common issues and solutions for the Auto Scaling Group demo.

## Table of Contents

1. [Setup Issues](#setup-issues)
2. [Instance Launch Issues](#instance-launch-issues)
3. [Scaling Issues](#scaling-issues)
4. [Load Balancer Issues](#load-balancer-issues)
5. [Networking Issues](#networking-issues)
6. [Monitoring Issues](#monitoring-issues)

---

## Setup Issues

### Error: "AWS CLI not found"

**Symptom:** Setup script fails with command not found

**Solution:**
```bash
# Install AWS CLI
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version
```

### Error: "Credentials not configured"

**Symptom:** AWS CLI commands fail with authentication error

**Solution:**
```bash
# Configure AWS credentials
aws configure

# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (e.g., us-east-1)
# - Default output format (json)

# Verify
aws sts get-caller-identity
```

### Error: "Insufficient permissions"

**Symptom:** Operations fail with AccessDenied

**Required IAM Permissions:**
- EC2: Full access
- Auto Scaling: Full access
- Elastic Load Balancing: Full access
- CloudWatch: Full access
- IAM: Create roles and instance profiles

**Solution:**
```bash
# Attach AdministratorAccess policy (for demo only)
# Or create custom policy with required permissions
```

---

## Instance Launch Issues

### Instances fail to launch

**Check 1: Service Limits**
```bash
# Check EC2 instance limits
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A \
  --region $AWS_REGION

# Request limit increase if needed
```

**Check 2: Launch Template**
```bash
# Verify launch template
aws ec2 describe-launch-template-versions \
  --launch-template-id $TEMPLATE_ID \
  --region $AWS_REGION

# Common issues:
# - Invalid AMI ID
# - Security group doesn't exist
# - IAM instance profile missing
```

**Check 3: Subnet Capacity**
```bash
# Check available IPs in subnet
aws ec2 describe-subnets \
  --subnet-ids $SUBNET1_ID $SUBNET2_ID \
  --region $AWS_REGION \
  --query 'Subnets[*].[SubnetId,AvailableIpAddressCount]'
```

### Instances launch but immediately terminate

**Check 1: User Data Script**
```bash
# SSH to instance before it terminates
ssh -i ~/.ssh/asg-demo-key.pem ec2-user@<instance-ip>

# Check cloud-init logs
sudo cat /var/log/cloud-init-output.log

# Common issues:
# - Syntax error in user data script
# - Missing dependencies
# - Network connectivity issues
```

**Check 2: Health Check Grace Period**
```bash
# Increase grace period
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name $ASG_NAME \
  --health-check-grace-period 600 \
  --region $AWS_REGION
```

### Instances stuck in "Pending" state

**Check 1: EC2 Status**
```bash
# Get instance status
aws ec2 describe-instance-status \
  --instance-ids <instance-id> \
  --region $AWS_REGION

# Check system status and instance status
```

**Check 2: Subnet Configuration**
```bash
# Verify subnet has route to internet
aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=$SUBNET1_ID" \
  --region $AWS_REGION

# Should have route: 0.0.0.0/0 -> igw-xxxxx
```

---

## Scaling Issues

### Scaling policy not triggering

**Check 1: CloudWatch Alarms**
```bash
# Check alarm state
aws cloudwatch describe-alarms \
  --alarm-names asg-demo-cpu-high \
  --region $AWS_REGION

# Alarm should be in ALARM state to trigger scaling
```

**Check 2: Metrics Publishing**
```bash
# Verify metrics are being published
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average \
  --region $AWS_REGION

# Should return data points
```

**Check 3: Cooldown Periods**
```bash
# Check if in cooldown
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region $AWS_REGION \
  --query 'AutoScalingGroups[0].DefaultCooldown'

# Wait for cooldown to expire
```

**Check 4: Suspended Processes**
```bash
# Check for suspended processes
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region $AWS_REGION \
  --query 'AutoScalingGroups[0].SuspendedProcesses'

# Resume if needed
aws autoscaling resume-processes \
  --auto-scaling-group-name $ASG_NAME \
  --region $AWS_REGION
```

### Scaling too slowly

**Solution 1: Reduce Cooldown**
```bash
# Reduce scale-out cooldown
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name $ASG_NAME \
  --policy-name target-tracking-cpu-policy \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration '{
    "TargetValue": 50.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ASGAverageCPUUtilization"
    },
    "ScaleOutCooldown": 30
  }' \
  --region $AWS_REGION
```

**Solution 2: Lower Thresholds**
```bash
# Trigger scaling at lower CPU
# Modify alarm threshold to 60% instead of 70%
```

### Scaling too aggressively

**Solution 1: Increase Cooldown**
```bash
# Increase cooldown to 600 seconds (10 minutes)
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name $ASG_NAME \
  --default-cooldown 600 \
  --region $AWS_REGION
```

**Solution 2: Adjust Thresholds**
```bash
# Increase alarm threshold
# Scale out at 80% CPU instead of 70%
```

### Not scaling in

**Check 1: Scale-In Protection**
```bash
# Check if instances are protected
aws autoscaling describe-auto-scaling-instances \
  --region $AWS_REGION \
  --query 'AutoScalingInstances[?AutoScalingGroupName==`'$ASG_NAME'`].[InstanceId,ProtectedFromScaleIn]'

# Remove protection if needed
aws autoscaling set-instance-protection \
  --instance-ids <instance-id> \
  --auto-scaling-group-name $ASG_NAME \
  --no-protected-from-scale-in \
  --region $AWS_REGION
```

**Check 2: Minimum Size**
```bash
# Verify min size allows scale-in
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region $AWS_REGION \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity]'

# Current capacity must be > min size to scale in
```

---

## Load Balancer Issues

### Cannot access ALB

**Check 1: ALB State**
```bash
# Verify ALB is active
aws elbv2 describe-load-balancers \
  --load-balancer-arns $ALB_ARN \
  --region $AWS_REGION \
  --query 'LoadBalancers[0].State'

# Should be "active"
```

**Check 2: Security Group**
```bash
# Verify ALB security group allows port 80
aws ec2 describe-security-groups \
  --group-ids $ALB_SG_ID \
  --region $AWS_REGION \
  --query 'SecurityGroups[0].IpPermissions'

# Should allow 0.0.0.0/0 on port 80
```

**Check 3: DNS Resolution**
```bash
# Test DNS resolution
nslookup $ALB_DNS

# Should return IP addresses
```

### All targets unhealthy

**Check 1: Health Check Path**
```bash
# Verify health check configuration
aws elbv2 describe-target-groups \
  --target-group-arns $TG_ARN \
  --region $AWS_REGION \
  --query 'TargetGroups[0].HealthCheckPath'

# Should be /health.html
```

**Check 2: Instance Security Group**
```bash
# Verify instances allow traffic from ALB
aws ec2 describe-security-groups \
  --group-ids $INSTANCE_SG_ID \
  --region $AWS_REGION \
  --query 'SecurityGroups[0].IpPermissions'

# Should allow port 80 from ALB security group
```

**Check 3: Web Server Status**
```bash
# SSH to instance
ssh -i ~/.ssh/asg-demo-key.pem ec2-user@<instance-ip>

# Check Apache status
sudo systemctl status httpd

# Check if health check file exists
curl http://localhost/health.html

# Should return "OK"
```

### 503 Service Unavailable

**Cause:** No healthy targets

**Solution:**
```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region $AWS_REGION

# Wait for instances to become healthy
# Or investigate why targets are unhealthy (see above)
```

---

## Networking Issues

### Instances have no internet access

**Check 1: Route Table**
```bash
# Verify route to internet gateway
aws ec2 describe-route-tables \
  --route-table-ids $RTB_ID \
  --region $AWS_REGION \
  --query 'RouteTables[0].Routes'

# Should have: 0.0.0.0/0 -> igw-xxxxx
```

**Check 2: Internet Gateway**
```bash
# Verify IGW is attached
aws ec2 describe-internet-gateways \
  --internet-gateway-ids $IGW_ID \
  --region $AWS_REGION \
  --query 'InternetGateways[0].Attachments'

# Should show attached to VPC
```

**Check 3: Public IP**
```bash
# Verify instances have public IPs
aws ec2 describe-instances \
  --filters "Name=tag:aws:autoscaling:groupName,Values=$ASG_NAME" \
  --region $AWS_REGION \
  --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress]'

# Should show public IPs
```

### Cannot SSH to instances

**Check 1: Security Group**
```bash
# Verify SSH is allowed from your IP
MY_IP=$(curl -s https://checkip.amazonaws.com)
echo "Your IP: $MY_IP"

aws ec2 describe-security-groups \
  --group-ids $INSTANCE_SG_ID \
  --region $AWS_REGION \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`]'

# Should allow your IP on port 22
```

**Check 2: Key Pair**
```bash
# Verify key pair exists and has correct permissions
ls -l ~/.ssh/asg-demo-key.pem

# Should be -r-------- (400)
# If not: chmod 400 ~/.ssh/asg-demo-key.pem
```

**Check 3: Instance State**
```bash
# Verify instance is running
aws ec2 describe-instances \
  --instance-ids <instance-id> \
  --region $AWS_REGION \
  --query 'Reservations[0].Instances[0].State.Name'

# Should be "running"
```

---

## Monitoring Issues

### No metrics in CloudWatch

**Check 1: Detailed Monitoring**
```bash
# Verify detailed monitoring is enabled
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region $AWS_REGION \
  --query 'AutoScalingGroups[0].EnabledMetrics'

# Enable if needed
aws autoscaling enable-metrics-collection \
  --auto-scaling-group-name $ASG_NAME \
  --granularity "1Minute" \
  --region $AWS_REGION
```

**Check 2: Wait Time**
```bash
# Metrics can take 5-10 minutes to appear
# Wait and check again
```

**Check 3: IAM Permissions**
```bash
# Verify instance role has CloudWatch permissions
aws iam get-role-policy \
  --role-name asg-demo-ec2-role \
  --policy-name CloudWatchAgentServerPolicy

# Should have cloudwatch:PutMetricData permission
```

### Dashboard not showing data

**Check 1: Dashboard Configuration**
```bash
# Verify dashboard exists
aws cloudwatch list-dashboards \
  --region $AWS_REGION

# Get dashboard body
aws cloudwatch get-dashboard \
  --dashboard-name asg-demo-dashboard \
  --region $AWS_REGION
```

**Check 2: Metric Names**
```bash
# Verify metric names are correct
aws cloudwatch list-metrics \
  --namespace AWS/EC2 \
  --region $AWS_REGION \
  --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME
```

---

## Getting Help

### View Logs

```bash
# ASG activity history
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $ASG_NAME \
  --max-records 20 \
  --region $AWS_REGION

# Instance system logs
aws ec2 get-console-output \
  --instance-id <instance-id> \
  --region $AWS_REGION

# CloudWatch Logs (if configured)
aws logs tail /aws/autoscaling/$ASG_NAME \
  --follow \
  --region $AWS_REGION
```

### AWS Support

- **Documentation:** https://docs.aws.amazon.com/autoscaling/
- **Forums:** https://forums.aws.amazon.com/
- **Support:** https://console.aws.amazon.com/support/

### Emergency Cleanup

If something goes wrong and you need to clean up immediately:

```bash
# Force delete ASG
aws autoscaling delete-auto-scaling-group \
  --auto-scaling-group-name $ASG_NAME \
  --force-delete \
  --region $AWS_REGION

# Delete ALB
aws elbv2 delete-load-balancer \
  --load-balancer-arn $ALB_ARN \
  --region $AWS_REGION

# Run full cleanup
./scripts/cleanup.sh
```
