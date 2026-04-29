# Quick Start Guide

Get your Auto Scaling Group demo running in 10 minutes.

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured
3. **jq** installed (`brew install jq` on macOS)
4. **hey** for load testing (`brew install hey` on macOS)

## Quick Setup (Automated)

```bash
# Clone or navigate to the demo directory
cd autoscaling-demo

# Run automated setup
./scripts/setup.sh

# Wait for completion (5-10 minutes)
```

The script will:
- Create VPC and networking
- Set up security groups
- Create IAM roles
- Build launch template
- Deploy load balancer
- Launch Auto Scaling Group
- Configure scaling policies

## Access Your Application

After setup completes, you'll see:

```
Application URL: http://asg-demo-alb-xxxxxxxxx.us-east-1.elb.amazonaws.com
```

Visit this URL in your browser to see:
- Instance information
- Real-time metrics
- Stress test controls

## Run Stress Tests

```bash
# Interactive stress test menu
./scripts/stress-test.sh

# Options:
# 1) CPU Stress - Trigger CPU-based scaling
# 2) Light Load - 100 req/s for 2 minutes
# 3) Medium Load - 500 req/s for 5 minutes
# 4) Heavy Load - 1000 req/s for 10 minutes
# 5) Spike Test - Sudden traffic spike
# 6) Comprehensive - All phases
```

## Monitor Scaling

```bash
# Real-time monitoring dashboard
./scripts/monitor.sh

# Shows:
# - Current capacity (min/desired/max)
# - Instance status and health
# - CPU utilization
# - Recent scaling activities
# - Load balancer metrics
```

## Manual Setup (Step-by-Step)

If you prefer manual setup or want to understand each component:

1. [Networking Setup](./docs/01-networking-setup.md) - VPC, subnets, routing
2. [Security Groups](./docs/02-security-groups.md) - ALB and instance security
3. [Launch Template](./docs/03-launch-template.md) - EC2 configuration
4. [Load Balancer](./docs/04-load-balancer.md) - ALB and target groups
5. [Auto Scaling Group](./docs/05-autoscaling-group.md) - ASG creation
6. [Scaling Policies](./docs/06-scaling-policies.md) - Configure scaling behavior
7. [Stress Testing](./docs/07-stress-testing.md) - Test scaling
8. [Monitoring](./docs/08-monitoring.md) - Visualize behavior

## Choosing Your Scaling Policy

The automated setup uses **Target Tracking** (recommended for most cases).

To use a different policy:

### Target Tracking (Default)
```bash
# Already configured - maintains 50% CPU
# Best for: Steady workloads
```

### Step Scaling
```bash
# Scale in steps based on severity
# Best for: Variable intensity workloads

# See docs/06-scaling-policies.md for setup
```

### Scheduled Scaling
```bash
# Scale based on time patterns
# Best for: Predictable business hours

# Example: Scale up at 9 AM, down at 6 PM
aws autoscaling put-scheduled-update-group-action \
  --auto-scaling-group-name asg-demo-group \
  --scheduled-action-name scale-up-morning \
  --recurrence "0 9 * * MON-FRI" \
  --desired-capacity 4
```

### Predictive Scaling
```bash
# ML-based forecasting
# Best for: Applications with historical patterns
# Requires: 24 hours of data

# See docs/06-scaling-policies.md for setup
```

## Common Commands

```bash
# Load configuration
source ~/asg-demo-config.sh

# Check ASG status
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region $AWS_REGION

# View scaling activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $ASG_NAME \
  --max-records 10 \
  --region $AWS_REGION

# Manual scale out
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name $ASG_NAME \
  --desired-capacity 4 \
  --region $AWS_REGION

# Manual scale in
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name $ASG_NAME \
  --desired-capacity 2 \
  --region $AWS_REGION

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region $AWS_REGION
```

## Troubleshooting

### Instances not launching
```bash
# Check ASG activity
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $ASG_NAME \
  --max-records 5 \
  --region $AWS_REGION

# Common issues:
# - EC2 instance limit reached
# - IAM role missing permissions
# - Launch template invalid
```

### Scaling not triggered
```bash
# Check CloudWatch alarms
aws cloudwatch describe-alarms \
  --alarm-name-prefix asg-demo \
  --region $AWS_REGION

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
```

### Cannot access application
```bash
# Check ALB status
aws elbv2 describe-load-balancers \
  --load-balancer-arns $ALB_ARN \
  --region $AWS_REGION

# Verify target health
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region $AWS_REGION

# Check security groups
aws ec2 describe-security-groups \
  --group-ids $ALB_SG_ID $INSTANCE_SG_ID \
  --region $AWS_REGION
```

## Cleanup

**Important:** Run cleanup to avoid ongoing charges!

```bash
# Delete all resources
./scripts/cleanup.sh

# Confirm when prompted
# This will delete:
# - Auto Scaling Group and instances
# - Load Balancer and target groups
# - Launch template
# - VPC and networking
# - Security groups
# - IAM roles
```

## Cost Estimate

Running this demo costs approximately:

- **EC2 instances:** $0.0104/hour × 2 instances = $0.0208/hour
- **Application Load Balancer:** $0.0225/hour
- **Data transfer:** Minimal for testing
- **CloudWatch:** Minimal for short-term testing

**Total:** ~$0.05/hour or **$0.10-$0.50 for a 2-hour demo**

## What You'll Learn

- How Auto Scaling Groups maintain desired capacity
- Different scaling policy types and when to use them
- How to trigger and observe scaling events
- Load balancer integration with ASG
- Health checks and auto-healing
- Monitoring and troubleshooting scaling behavior

## Next Steps

1. Run the automated setup
2. Access the application URL
3. Run stress tests to trigger scaling
4. Monitor scaling behavior in real-time
5. Experiment with different scaling policies
6. Clean up resources when done

## Support

- **Issues:** Open an issue in this repository
- **AWS Documentation:** https://docs.aws.amazon.com/autoscaling/
- **Detailed Guides:** See `docs/` directory

## License

MIT License - Free to use for learning and demonstrations.
