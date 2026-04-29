# Step 6: Configure Scaling Policies

Configure different types of scaling policies to automatically adjust capacity based on demand.

## Overview

We'll implement multiple scaling policy types:
1. **Target Tracking Scaling** - Maintain target CPU utilization
2. **Step Scaling** - Scale in steps based on alarm severity
3. **Simple Scaling** - Basic threshold-based scaling
4. **Scheduled Scaling** - Time-based scaling
5. **Predictive Scaling** - ML-based forecasting

## Choosing the Right Policy

| Policy Type | Best For | Complexity | Response Time |
|-------------|----------|------------|---------------|
| Target Tracking | Steady workloads | Low | Fast |
| Step Scaling | Variable intensity | Medium | Fast |
| Simple Scaling | Basic needs | Low | Moderate |
| Scheduled | Predictable patterns | Low | Instant |
| Predictive | Historical patterns | High | Proactive |

## Step-by-Step Instructions

### 1. Load Configuration

```bash
source ~/asg-demo-config.sh
```

## Option 1: Target Tracking Scaling (Recommended)

Best for most use cases. Automatically adjusts capacity to maintain target metric.

### Create Target Tracking Policy

```bash
# Create policy configuration
cat > /tmp/target-tracking-policy.json << 'EOF'
{
  "TargetValue": 50.0,
  "PredefinedMetricSpecification": {
    "PredefinedMetricType": "ASGAverageCPUUtilization"
  },
  "ScaleInCooldown": 300,
  "ScaleOutCooldown": 60
}
EOF

# Create the policy
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name $ASG_NAME \
  --policy-name target-tracking-cpu-policy \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration file:///tmp/target-tracking-policy.json \
  --region $AWS_REGION

echo "Target tracking policy created"
```

### Configuration Explained

- **Target Value:** 50% CPU utilization
- **Scale Out Cooldown:** 60 seconds (respond quickly to load)
- **Scale In Cooldown:** 300 seconds (be conservative removing capacity)

### Other Target Tracking Metrics

**ALB Request Count Per Target:**
```json
{
  "TargetValue": 1000.0,
  "PredefinedMetricSpecification": {
    "PredefinedMetricType": "ALBRequestCountPerTarget",
    "ResourceLabel": "app/asg-demo-alb/xxx/targetgroup/asg-demo-tg/yyy"
  }
}
```

**Network In:**
```json
{
  "TargetValue": 10485760.0,
  "PredefinedMetricSpecification": {
    "PredefinedMetricType": "ASGAverageNetworkIn"
  }
}
```

## Option 2: Step Scaling

Scale in steps based on alarm severity. Good for workloads with varying intensity.

### Create CloudWatch Alarms

```bash
# High CPU alarm (scale out)
aws cloudwatch put-metric-alarm \
  --alarm-name asg-demo-cpu-high \
  --alarm-description "Scale out when CPU > 70%" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 70 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
  --region $AWS_REGION

# Low CPU alarm (scale in)
aws cloudwatch put-metric-alarm \
  --alarm-name asg-demo-cpu-low \
  --alarm-description "Scale in when CPU < 30%" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 30 \
  --comparison-operator LessThanThreshold \
  --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
  --region $AWS_REGION

echo "CloudWatch alarms created"
```

### Create Step Scaling Policies

```bash
# Scale out policy (add instances in steps)
cat > /tmp/step-scale-out.json << 'EOF'
{
  "AdjustmentType": "PercentChangeInCapacity",
  "MetricAggregationType": "Average",
  "StepAdjustments": [
    {
      "MetricIntervalLowerBound": 0,
      "MetricIntervalUpperBound": 10,
      "ScalingAdjustment": 10
    },
    {
      "MetricIntervalLowerBound": 10,
      "MetricIntervalUpperBound": 20,
      "ScalingAdjustment": 20
    },
    {
      "MetricIntervalLowerBound": 20,
      "ScalingAdjustment": 30
    }
  ]
}
EOF

SCALE_OUT_POLICY_ARN=$(aws autoscaling put-scaling-policy \
  --auto-scaling-group-name $ASG_NAME \
  --policy-name step-scale-out-policy \
  --policy-type StepScaling \
  --adjustment-type PercentChangeInCapacity \
  --metric-aggregation-type Average \
  --step-adjustments file:///tmp/step-scale-out.json \
  --region $AWS_REGION \
  --query 'PolicyARN' \
  --output text)

# Scale in policy (remove instances)
cat > /tmp/step-scale-in.json << 'EOF'
{
  "AdjustmentType": "ChangeInCapacity",
  "MetricAggregationType": "Average",
  "StepAdjustments": [
    {
      "MetricIntervalUpperBound": 0,
      "ScalingAdjustment": -1
    }
  ]
}
EOF

SCALE_IN_POLICY_ARN=$(aws autoscaling put-scaling-policy \
  --auto-scaling-group-name $ASG_NAME \
  --policy-name step-scale-in-policy \
  --policy-type StepScaling \
  --adjustment-type ChangeInCapacity \
  --metric-aggregation-type Average \
  --step-adjustments file:///tmp/step-scale-in.json \
  --region $AWS_REGION \
  --query 'PolicyARN' \
  --output text)

echo "Step scaling policies created"
```

### Link Alarms to Policies

```bash
# Link high CPU alarm to scale out policy
aws cloudwatch put-metric-alarm \
  --alarm-name asg-demo-cpu-high \
  --alarm-actions $SCALE_OUT_POLICY_ARN \
  --region $AWS_REGION

# Link low CPU alarm to scale in policy
aws cloudwatch put-metric-alarm \
  --alarm-name asg-demo-cpu-low \
  --alarm-actions $SCALE_IN_POLICY_ARN \
  --region $AWS_REGION

echo "Alarms linked to policies"
```

### Step Scaling Logic Explained

**Scale Out Steps:**
- CPU 70-80%: Add 10% capacity (round up)
- CPU 80-90%: Add 20% capacity
- CPU >90%: Add 30% capacity

**Scale In:**
- CPU <30% for 10 minutes: Remove 1 instance

## Option 3: Simple Scaling

Basic threshold-based scaling. Simplest to understand.

### Create Simple Scaling Policies

```bash
# Scale out policy
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name $ASG_NAME \
  --policy-name simple-scale-out \
  --policy-type SimpleScaling \
  --adjustment-type ChangeInCapacity \
  --scaling-adjustment 1 \
  --cooldown 300 \
  --region $AWS_REGION

# Scale in policy
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name $ASG_NAME \
  --policy-name simple-scale-in \
  --policy-type SimpleScaling \
  --adjustment-type ChangeInCapacity \
  --scaling-adjustment -1 \
  --cooldown 300 \
  --region $AWS_REGION

echo "Simple scaling policies created"
```

## Option 4: Scheduled Scaling

Scale based on predictable time patterns.

### Create Scheduled Actions

```bash
# Scale up for business hours (9 AM)
aws autoscaling put-scheduled-update-group-action \
  --auto-scaling-group-name $ASG_NAME \
  --scheduled-action-name scale-up-morning \
  --recurrence "0 9 * * MON-FRI" \
  --desired-capacity 4 \
  --min-size 2 \
  --max-size 6 \
  --region $AWS_REGION

# Scale down after hours (6 PM)
aws autoscaling put-scheduled-update-group-action \
  --auto-scaling-group-name $ASG_NAME \
  --scheduled-action-name scale-down-evening \
  --recurrence "0 18 * * MON-FRI" \
  --desired-capacity 2 \
  --min-size 1 \
  --max-size 5 \
  --region $AWS_REGION

# Weekend minimal capacity
aws autoscaling put-scheduled-update-group-action \
  --auto-scaling-group-name $ASG_NAME \
  --scheduled-action-name scale-down-weekend \
  --recurrence "0 0 * * SAT" \
  --desired-capacity 1 \
  --min-size 1 \
  --max-size 3 \
  --region $AWS_REGION

echo "Scheduled actions created"
```

### Cron Expression Format

```
* * * * * *
│ │ │ │ │ │
│ │ │ │ │ └─ Day of week (0-6, 0=Sunday)
│ │ │ │ └─── Month (1-12)
│ │ │ └───── Day of month (1-31)
│ │ └─────── Hour (0-23)
│ └───────── Minute (0-59)
└─────────── Second (0-59, optional)
```

**Examples:**
- `0 9 * * MON-FRI` - 9 AM weekdays
- `0 */4 * * *` - Every 4 hours
- `0 0 1 * *` - First day of month

## Option 5: Predictive Scaling

Uses machine learning to forecast load. Requires 24 hours of historical data.

### Create Predictive Scaling Policy

```bash
cat > /tmp/predictive-scaling-policy.json << 'EOF'
{
  "MetricSpecifications": [
    {
      "TargetValue": 50.0,
      "PredefinedMetricPairSpecification": {
        "PredefinedMetricType": "ASGCPUUtilization"
      }
    }
  ],
  "Mode": "ForecastAndScale",
  "SchedulingBufferTime": 600
}
EOF

aws autoscaling put-scaling-policy \
  --auto-scaling-group-name $ASG_NAME \
  --policy-name predictive-scaling-policy \
  --policy-type PredictiveScaling \
  --predictive-scaling-configuration file:///tmp/predictive-scaling-policy.json \
  --region $AWS_REGION

echo "Predictive scaling policy created"
```

### Configuration Explained

- **Mode:** `ForecastAndScale` (also creates capacity proactively)
- **SchedulingBufferTime:** 600 seconds (scale 10 minutes before predicted load)
- **Target Value:** 50% CPU utilization

**Modes:**
- `ForecastOnly`: Generate forecasts but don't scale
- `ForecastAndScale`: Generate forecasts and scale proactively

## Viewing Policies

```bash
# List all policies
aws autoscaling describe-policies \
  --auto-scaling-group-name $ASG_NAME \
  --region $AWS_REGION \
  --query 'ScalingPolicies[*].[PolicyName,PolicyType,Enabled]' \
  --output table

# View specific policy
aws autoscaling describe-policies \
  --auto-scaling-group-name $ASG_NAME \
  --policy-names target-tracking-cpu-policy \
  --region $AWS_REGION
```

## Deleting Policies

```bash
# Delete specific policy
aws autoscaling delete-policy \
  --auto-scaling-group-name $ASG_NAME \
  --policy-name target-tracking-cpu-policy \
  --region $AWS_REGION

# Delete scheduled action
aws autoscaling delete-scheduled-action \
  --auto-scaling-group-name $ASG_NAME \
  --scheduled-action-name scale-up-morning \
  --region $AWS_REGION
```

## Best Practices

### 1. Use Target Tracking for Most Cases
- Simplest to configure
- Automatically creates CloudWatch alarms
- Handles both scale out and scale in

### 2. Combine Multiple Policies
```bash
# Target tracking for CPU
# + Scheduled scaling for known patterns
# + Step scaling for extreme conditions
```

### 3. Set Appropriate Cooldowns
- **Scale Out:** Short cooldown (60s) - respond quickly
- **Scale In:** Long cooldown (300s) - be conservative

### 4. Monitor Policy Effectiveness
```bash
# View scaling activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $ASG_NAME \
  --max-records 20 \
  --region $AWS_REGION
```

### 5. Test Policies Thoroughly
- Simulate load before production
- Monitor costs during testing
- Adjust thresholds based on results

## Troubleshooting

**Issue:** Policy not triggering
- Check CloudWatch alarm state
- Verify metric is being published
- Review cooldown periods
- Check if processes are suspended

**Issue:** Scaling too aggressively
- Increase cooldown periods
- Adjust thresholds
- Use step scaling instead of simple scaling

**Issue:** Scaling too slowly
- Decrease cooldown periods
- Lower thresholds
- Use multiple policies

**Issue:** Predictive scaling not working
- Ensure 24 hours of historical data exists
- Check metric is being collected
- Verify policy mode is `ForecastAndScale`

## Next Steps

Proceed to [Step 7: Stress Testing](./07-stress-testing.md)
