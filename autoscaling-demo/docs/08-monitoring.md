# Step 8: Monitoring and Visualization

Monitor and visualize Auto Scaling Group behavior using CloudWatch and custom dashboards.

## Overview

We'll create:
- CloudWatch Dashboard
- Custom metrics
- Alarms for monitoring
- Log insights queries
- Real-time monitoring scripts

## Step 1: Create CloudWatch Dashboard

### 1. Load Configuration

```bash
source ~/asg-demo-config.sh
```

### 2. Create Dashboard JSON

```bash
# Get ALB full name for metrics
ALB_FULL_NAME=$(echo $ALB_ARN | cut -d':' -f6 | cut -d'/' -f2-4)

# Create dashboard configuration
cat > /tmp/dashboard.json << EOF
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/EC2", "CPUUtilization", {"stat": "Average", "label": "Avg CPU"}],
          ["...", {"stat": "Maximum", "label": "Max CPU"}]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "$AWS_REGION",
        "title": "CPU Utilization",
        "period": 60,
        "yAxis": {
          "left": {
            "min": 0,
            "max": 100
          }
        }
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/AutoScaling", "GroupDesiredCapacity", {"label": "Desired"}],
          [".", "GroupInServiceInstances", {"label": "In Service"}],
          [".", "GroupMinSize", {"label": "Min"}],
          [".", "GroupMaxSize", {"label": "Max"}]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "$AWS_REGION",
        "title": "Auto Scaling Group Capacity",
        "period": 60,
        "dimensions": {
          "AutoScalingGroupName": "$ASG_NAME"
        }
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ApplicationELB", "RequestCount", {"stat": "Sum", "label": "Requests"}],
          [".", "TargetResponseTime", {"stat": "Average", "label": "Response Time"}]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "$AWS_REGION",
        "title": "Load Balancer Metrics",
        "period": 60,
        "dimensions": {
          "LoadBalancer": "$ALB_FULL_NAME"
        }
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ApplicationELB", "HealthyHostCount", {"label": "Healthy"}],
          [".", "UnHealthyHostCount", {"label": "Unhealthy"}]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "$AWS_REGION",
        "title": "Target Health",
        "period": 60,
        "dimensions": {
          "TargetGroup": "$(echo $TG_ARN | cut -d':' -f6)",
          "LoadBalancer": "$ALB_FULL_NAME"
        }
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/EC2", "NetworkIn", {"stat": "Sum"}],
          [".", "NetworkOut", {"stat": "Sum"}]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "$AWS_REGION",
        "title": "Network Traffic",
        "period": 60
      }
    },
    {
      "type": "log",
      "properties": {
        "query": "SOURCE '/aws/autoscaling/$ASG_NAME'\n| fields @timestamp, @message\n| sort @timestamp desc\n| limit 20",
        "region": "$AWS_REGION",
        "title": "Recent Scaling Activities",
        "stacked": false
      }
    }
  ]
}
EOF
```

### 3. Create Dashboard

```bash
aws cloudwatch put-dashboard \
  --dashboard-name asg-demo-dashboard \
  --dashboard-body file:///tmp/dashboard.json \
  --region $AWS_REGION

echo "Dashboard created: asg-demo-dashboard"
echo "View at: https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#dashboards:name=asg-demo-dashboard"
```

## Step 2: Create Monitoring Alarms

### Critical Alarms

```bash
# High CPU alarm
aws cloudwatch put-metric-alarm \
  --alarm-name asg-demo-critical-cpu \
  --alarm-description "Critical: CPU > 90% for 5 minutes" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 90 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
  --treat-missing-data notBreaching \
  --region $AWS_REGION

# All targets unhealthy
aws cloudwatch put-metric-alarm \
  --alarm-name asg-demo-no-healthy-targets \
  --alarm-description "Critical: No healthy targets" \
  --metric-name HealthyHostCount \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 1 \
  --comparison-operator LessThanThreshold \
  --dimensions Name=TargetGroup,Value=$(echo $TG_ARN | cut -d':' -f6) Name=LoadBalancer,Value=$ALB_FULL_NAME \
  --treat-missing-data breaching \
  --region $AWS_REGION

# High error rate
aws cloudwatch put-metric-alarm \
  --alarm-name asg-demo-high-error-rate \
  --alarm-description "Warning: 5xx errors > 10" \
  --metric-name HTTPCode_Target_5XX_Count \
  --namespace AWS/ApplicationELB \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=LoadBalancer,Value=$ALB_FULL_NAME \
  --treat-missing-data notBreaching \
  --region $AWS_REGION

echo "Monitoring alarms created"
```

## Step 3: Custom Metrics

### Create Custom Metric Script

```bash
cat > /tmp/publish-custom-metrics.sh << 'EOF'
#!/bin/bash

source ~/asg-demo-config.sh

while true; do
  # Get instance count
  INSTANCE_COUNT=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $ASG_NAME \
    --region $AWS_REGION \
    --query 'AutoScalingGroups[0].Instances | length(@)' \
    --output text)
  
  # Get healthy target count
  HEALTHY_COUNT=$(aws elbv2 describe-target-health \
    --target-group-arn $TG_ARN \
    --region $AWS_REGION \
    --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' \
    --output text)
  
  # Get desired capacity
  DESIRED=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $ASG_NAME \
    --region $AWS_REGION \
    --query 'AutoScalingGroups[0].DesiredCapacity' \
    --output text)
  
  # Calculate capacity utilization
  if [ "$DESIRED" -gt 0 ]; then
    UTILIZATION=$(echo "scale=2; ($INSTANCE_COUNT / $DESIRED) * 100" | bc)
  else
    UTILIZATION=0
  fi
  
  # Publish metrics
  aws cloudwatch put-metric-data \
    --namespace "ASG/Demo" \
    --metric-name InstanceCount \
    --value $INSTANCE_COUNT \
    --dimensions AutoScalingGroup=$ASG_NAME \
    --region $AWS_REGION
  
  aws cloudwatch put-metric-data \
    --namespace "ASG/Demo" \
    --metric-name HealthyTargets \
    --value $HEALTHY_COUNT \
    --dimensions AutoScalingGroup=$ASG_NAME \
    --region $AWS_REGION
  
  aws cloudwatch put-metric-data \
    --namespace "ASG/Demo" \
    --metric-name CapacityUtilization \
    --value $UTILIZATION \
    --unit Percent \
    --dimensions AutoScalingGroup=$ASG_NAME \
    --region $AWS_REGION
  
  echo "$(date): Published metrics - Instances: $INSTANCE_COUNT, Healthy: $HEALTHY_COUNT, Utilization: $UTILIZATION%"
  
  sleep 60
done
EOF

chmod +x /tmp/publish-custom-metrics.sh
```

### Run Custom Metrics Collection

```bash
# Run in background
nohup /tmp/publish-custom-metrics.sh > /tmp/custom-metrics.log 2>&1 &
echo $! > /tmp/custom-metrics.pid

echo "Custom metrics collection started"
echo "PID: $(cat /tmp/custom-metrics.pid)"
echo "Log: /tmp/custom-metrics.log"
```

## Step 4: Real-Time Monitoring

### Create Monitoring Script

```bash
cat > /tmp/monitor-asg.sh << 'EOF'
#!/bin/bash

source ~/asg-demo-config.sh

while true; do
  clear
  echo "=========================================="
  echo "  Auto Scaling Group Monitor"
  echo "  $(date)"
  echo "=========================================="
  echo ""
  
  # ASG Status
  echo "=== Auto Scaling Group Status ==="
  ASG_INFO=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $ASG_NAME \
    --region $AWS_REGION \
    --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]' \
    --output text)
  
  echo "Min: $(echo $ASG_INFO | awk '{print $1}')"
  echo "Desired: $(echo $ASG_INFO | awk '{print $2}')"
  echo "Max: $(echo $ASG_INFO | awk '{print $3}')"
  echo ""
  
  # Instance Status
  echo "=== Instance Status ==="
  aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $ASG_NAME \
    --region $AWS_REGION \
    --query 'AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus,AvailabilityZone]' \
    --output table
  echo ""
  
  # Target Health
  echo "=== Target Health ==="
  aws elbv2 describe-target-health \
    --target-group-arn $TG_ARN \
    --region $AWS_REGION \
    --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
    --output table
  echo ""
  
  # CPU Utilization
  echo "=== CPU Utilization (Last 2 minutes) ==="
  CPU=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/EC2 \
    --metric-name CPUUtilization \
    --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
    --start-time $(date -u -d '2 minutes ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 60 \
    --statistics Average \
    --region $AWS_REGION \
    --query 'Datapoints[-1].Average' \
    --output text)
  
  if [ "$CPU" != "None" ]; then
    printf "Average: %.2f%%\n" $CPU
  else
    echo "No data available"
  fi
  echo ""
  
  # Recent Activities
  echo "=== Recent Scaling Activities ==="
  aws autoscaling describe-scaling-activities \
    --auto-scaling-group-name $ASG_NAME \
    --max-records 3 \
    --region $AWS_REGION \
    --query 'Activities[*].[StartTime,StatusCode,Description]' \
    --output table
  echo ""
  
  # ALB Metrics
  echo "=== Load Balancer Metrics (Last minute) ==="
  REQUESTS=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/ApplicationELB \
    --metric-name RequestCount \
    --dimensions Name=LoadBalancer,Value=$ALB_FULL_NAME \
    --start-time $(date -u -d '1 minute ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 60 \
    --statistics Sum \
    --region $AWS_REGION \
    --query 'Datapoints[-1].Sum' \
    --output text)
  
  if [ "$REQUESTS" != "None" ]; then
    echo "Requests: $REQUESTS"
  else
    echo "Requests: 0"
  fi
  
  echo ""
  echo "Press Ctrl+C to exit"
  
  sleep 10
done
EOF

chmod +x /tmp/monitor-asg.sh
```

### Run Monitor

```bash
/tmp/monitor-asg.sh
```

## Step 5: Log Analysis

### Query Scaling Activities

```bash
# Get all scaling activities from last hour
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $ASG_NAME \
  --max-records 100 \
  --region $AWS_REGION \
  --query 'Activities[?StartTime>=`'$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S)'`].[StartTime,StatusCode,Cause,Description]' \
  --output table
```

### Analyze Scaling Patterns

```bash
cat > /tmp/analyze-scaling.sh << 'EOF'
#!/bin/bash

source ~/asg-demo-config.sh

echo "=== Scaling Analysis ==="
echo ""

# Total scaling activities
TOTAL=$(aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $ASG_NAME \
  --region $AWS_REGION \
  --query 'length(Activities)' \
  --output text)

echo "Total scaling activities: $TOTAL"

# Successful vs failed
SUCCESSFUL=$(aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $ASG_NAME \
  --region $AWS_REGION \
  --query 'length(Activities[?StatusCode==`Successful`])' \
  --output text)

FAILED=$(aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $ASG_NAME \
  --region $AWS_REGION \
  --query 'length(Activities[?StatusCode==`Failed`])' \
  --output text)

echo "Successful: $SUCCESSFUL"
echo "Failed: $FAILED"
echo ""

# Scale out vs scale in
SCALE_OUT=$(aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $ASG_NAME \
  --region $AWS_REGION \
  --query 'length(Activities[?contains(Description, `Launching`)])' \
  --output text)

SCALE_IN=$(aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $ASG_NAME \
  --region $AWS_REGION \
  --query 'length(Activities[?contains(Description, `Terminating`)])' \
  --output text)

echo "Scale out events: $SCALE_OUT"
echo "Scale in events: $SCALE_IN"
echo ""

# Average time to launch
echo "Recent launch times:"
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $ASG_NAME \
  --max-records 10 \
  --region $AWS_REGION \
  --query 'Activities[?contains(Description, `Launching`) && StatusCode==`Successful`].[StartTime,EndTime]' \
  --output table

EOF

chmod +x /tmp/analyze-scaling.sh
/tmp/analyze-scaling.sh
```

## Step 6: Export Data for Visualization

### Export to CSV

```bash
cat > /tmp/export-metrics.sh << 'EOF'
#!/bin/bash

source ~/asg-demo-config.sh

OUTPUT_DIR="/tmp/asg-metrics"
mkdir -p $OUTPUT_DIR

echo "Exporting metrics to $OUTPUT_DIR"

# CPU metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum,Minimum \
  --region $AWS_REGION \
  --query 'Datapoints | sort_by(@, &Timestamp)[*].[Timestamp,Average,Maximum,Minimum]' \
  --output text | \
  awk 'BEGIN {print "Timestamp,Average,Maximum,Minimum"} {print $1","$2","$3","$4}' > $OUTPUT_DIR/cpu.csv

# Capacity metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/AutoScaling \
  --metric-name GroupDesiredCapacity \
  --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region $AWS_REGION \
  --query 'Datapoints | sort_by(@, &Timestamp)[*].[Timestamp,Average]' \
  --output text | \
  awk 'BEGIN {print "Timestamp,Capacity"} {print $1","$2}' > $OUTPUT_DIR/capacity.csv

# Request count
ALB_FULL_NAME=$(echo $ALB_ARN | cut -d':' -f6 | cut -d'/' -f2-4)
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=$ALB_FULL_NAME \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum \
  --region $AWS_REGION \
  --query 'Datapoints | sort_by(@, &Timestamp)[*].[Timestamp,Sum]' \
  --output text | \
  awk 'BEGIN {print "Timestamp,Requests"} {print $1","$2}' > $OUTPUT_DIR/requests.csv

echo "Export complete:"
ls -lh $OUTPUT_DIR/

EOF

chmod +x /tmp/export-metrics.sh
/tmp/export-metrics.sh
```

## Step 7: Cleanup Monitoring

### Stop Custom Metrics Collection

```bash
# Stop custom metrics
if [ -f /tmp/custom-metrics.pid ]; then
  kill $(cat /tmp/custom-metrics.pid)
  rm /tmp/custom-metrics.pid
  echo "Custom metrics collection stopped"
fi
```

## Troubleshooting

**Issue:** Dashboard not showing data
- Wait 5-10 minutes for metrics to populate
- Verify metric names and dimensions are correct
- Check if instances are publishing metrics

**Issue:** Alarms not triggering
- Verify alarm configuration
- Check if metrics are being published
- Review alarm history in CloudWatch console

**Issue:** Custom metrics not appearing
- Check script is running: `ps aux | grep publish-custom-metrics`
- Review logs: `tail -f /tmp/custom-metrics.log`
- Verify IAM permissions for CloudWatch

## Next Steps

You've completed the Auto Scaling Group demonstration! 

To clean up all resources, proceed to the [Cleanup Guide](../README.md#cleanup)
