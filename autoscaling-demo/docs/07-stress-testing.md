# Step 7: Stress Testing

Stress test your Auto Scaling Group to visualize scaling behavior in action.

## Overview

We'll perform different types of stress tests:
1. **CPU Stress Test** - Trigger CPU-based scaling
2. **Load Test** - Simulate real user traffic
3. **Sustained Load** - Test scaling stability
4. **Spike Test** - Test rapid scaling response

## Prerequisites

Install required tools:

```bash
# For macOS
brew install apache-bench
brew install hey

# For Linux
sudo apt-get install apache2-utils  # for ab
# or
sudo yum install httpd-tools  # for ab

# Install hey (modern load testing tool)
go install github.com/rakyll/hey@latest
# or download binary from https://github.com/rakyll/hey/releases
```

## Test 1: CPU Stress Test

Trigger scaling by stressing CPU on instances.

### 1. Load Configuration

```bash
source ~/asg-demo-config.sh
```

### 2. Baseline Metrics

```bash
# Check current state
echo "Current ASG State:"
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region $AWS_REGION \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]' \
  --output table

# Check current CPU
echo ""
echo "Current CPU Utilization:"
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average \
  --region $AWS_REGION \
  --query 'Datapoints[-1].Average' \
  --output text
```

### 3. Start CPU Stress via Web Interface

```bash
# Get ALB DNS
echo "Access the application at: http://$ALB_DNS"
echo ""
echo "Click 'Start CPU Stress' button on the web page"
echo "This will stress CPU for 5 minutes"
```

### 4. Start CPU Stress via API

```bash
# Get instance IDs
INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region $AWS_REGION \
  --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
  --output text)

# Stress all instances
for INSTANCE_ID in $INSTANCE_IDS; do
  PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --region $AWS_REGION \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)
  
  echo "Starting stress on $INSTANCE_ID ($PUBLIC_IP)"
  curl -X POST http://$PUBLIC_IP/stress/start
  echo ""
done
```

### 5. Monitor Scaling Activity

```bash
# Watch in real-time (press Ctrl+C to stop)
watch -n 10 "echo 'ASG Status:' && \
  aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $ASG_NAME \
    --region $AWS_REGION \
    --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]' \
    --output table && \
  echo '' && \
  echo 'Instance Count:' && \
  aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $ASG_NAME \
    --region $AWS_REGION \
    --query 'AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus]' \
    --output table && \
  echo '' && \
  echo 'Recent Activities:' && \
  aws autoscaling describe-scaling-activities \
    --auto-scaling-group-name $ASG_NAME \
    --max-records 3 \
    --region $AWS_REGION \
    --query 'Activities[*].[StartTime,StatusCode,Description]' \
    --output table"
```

### 6. Monitor CloudWatch Metrics

```bash
# View CPU metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average,Maximum \
  --region $AWS_REGION \
  --query 'Datapoints | sort_by(@, &Timestamp)[-10:].[Timestamp,Average,Maximum]' \
  --output table
```

## Test 2: HTTP Load Test

Simulate real user traffic to trigger scaling.

### Using Apache Bench (ab)

```bash
# Light load - 100 requests, 10 concurrent
ab -n 100 -c 10 http://$ALB_DNS/

# Medium load - 1000 requests, 50 concurrent
ab -n 1000 -c 50 http://$ALB_DNS/

# Heavy load - 10000 requests, 100 concurrent
ab -n 10000 -c 100 http://$ALB_DNS/

# Sustained load - 5 minutes
ab -t 300 -c 50 http://$ALB_DNS/
```

### Using hey (Recommended)

```bash
# 1000 requests, 50 workers
hey -n 1000 -c 50 http://$ALB_DNS/

# Sustained load for 5 minutes
hey -z 5m -c 50 http://$ALB_DNS/

# Rate-limited load (100 requests/second)
hey -z 5m -q 100 http://$ALB_DNS/

# With detailed output
hey -n 1000 -c 50 -m GET http://$ALB_DNS/ > load-test-results.txt
```

### Monitor During Load Test

```bash
# In another terminal, monitor metrics
while true; do
  clear
  echo "=== Auto Scaling Group Status ==="
  aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $ASG_NAME \
    --region $AWS_REGION \
    --query 'AutoScalingGroups[0].[DesiredCapacity]' \
    --output text | xargs -I {} echo "Desired Capacity: {}"
  
  echo ""
  echo "=== Target Health ==="
  aws elbv2 describe-target-health \
    --target-group-arn $TG_ARN \
    --region $AWS_REGION \
    --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
    --output table
  
  echo ""
  echo "=== ALB Metrics ==="
  aws cloudwatch get-metric-statistics \
    --namespace AWS/ApplicationELB \
    --metric-name RequestCount \
    --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d':' -f6 | cut -d'/' -f2-4) \
    --start-time $(date -u -d '2 minutes ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 60 \
    --statistics Sum \
    --region $AWS_REGION \
    --query 'Datapoints[-1].Sum' \
    --output text | xargs -I {} echo "Requests/min: {}"
  
  sleep 10
done
```

## Test 3: Spike Test

Test how quickly ASG responds to sudden load spikes.

### Create Spike Test Script

```bash
cat > /tmp/spike-test.sh << 'EOF'
#!/bin/bash

ALB_DNS=$1
DURATION=${2:-60}

echo "Starting spike test for $DURATION seconds..."
echo "Target: http://$ALB_DNS"
echo ""

# Baseline
echo "Phase 1: Baseline (10 seconds)"
hey -z 10s -c 10 http://$ALB_DNS/ > /dev/null 2>&1

sleep 5

# Spike
echo "Phase 2: Spike (30 seconds)"
hey -z 30s -c 200 http://$ALB_DNS/ > /dev/null 2>&1

sleep 5

# Sustained
echo "Phase 3: Sustained ($DURATION seconds)"
hey -z ${DURATION}s -c 100 http://$ALB_DNS/

echo ""
echo "Spike test complete"
EOF

chmod +x /tmp/spike-test.sh
```

### Run Spike Test

```bash
# Run spike test
/tmp/spike-test.sh $ALB_DNS 120

# Monitor scaling response time
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $ASG_NAME \
  --max-records 10 \
  --region $AWS_REGION \
  --query 'Activities[*].[StartTime,EndTime,StatusCode,Description]' \
  --output table
```

## Test 4: Scale-In Test

Test how ASG scales down when load decreases.

### 1. Stop All Stress Tests

```bash
# Stop stress on all instances
INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region $AWS_REGION \
  --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
  --output text)

for INSTANCE_ID in $INSTANCE_IDS; do
  PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --region $AWS_REGION \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)
  
  echo "Stopping stress on $INSTANCE_ID"
  curl -X POST http://$PUBLIC_IP/stress/stop 2>/dev/null
done

echo ""
echo "All stress tests stopped"
echo "Wait 5-10 minutes for scale-in to occur"
```

### 2. Monitor Scale-In

```bash
# Watch scale-in activity
watch -n 30 "aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region $AWS_REGION \
  --query 'AutoScalingGroups[0].[DesiredCapacity]' \
  --output text | xargs -I {} echo 'Desired Capacity: {}' && \
  echo '' && \
  aws autoscaling describe-scaling-activities \
    --auto-scaling-group-name $ASG_NAME \
    --max-records 5 \
    --region $AWS_REGION \
    --query 'Activities[*].[StartTime,StatusCode,Description]' \
    --output table"
```

## Test 5: Comprehensive Load Test

Simulate realistic traffic patterns.

### Create Comprehensive Test Script

```bash
cat > /tmp/comprehensive-test.sh << 'EOF'
#!/bin/bash

ALB_DNS=$1

echo "=== Comprehensive Load Test ==="
echo "Target: http://$ALB_DNS"
echo ""

# Phase 1: Warm-up
echo "Phase 1: Warm-up (2 minutes)"
hey -z 2m -c 10 -q 10 http://$ALB_DNS/ > /dev/null 2>&1
sleep 30

# Phase 2: Gradual increase
echo "Phase 2: Gradual increase (3 minutes)"
hey -z 1m -c 20 -q 20 http://$ALB_DNS/ > /dev/null 2>&1 &
sleep 60
hey -z 1m -c 40 -q 40 http://$ALB_DNS/ > /dev/null 2>&1 &
sleep 60
hey -z 1m -c 60 -q 60 http://$ALB_DNS/ > /dev/null 2>&1 &
wait
sleep 30

# Phase 3: Peak load
echo "Phase 3: Peak load (5 minutes)"
hey -z 5m -c 100 -q 100 http://$ALB_DNS/ > /tmp/peak-results.txt
sleep 30

# Phase 4: Cool down
echo "Phase 4: Cool down (2 minutes)"
hey -z 2m -c 20 -q 20 http://$ALB_DNS/ > /dev/null 2>&1

echo ""
echo "Test complete. Results saved to /tmp/peak-results.txt"
EOF

chmod +x /tmp/comprehensive-test.sh
```

### Run Comprehensive Test

```bash
# Run in background
/tmp/comprehensive-test.sh $ALB_DNS &

# Monitor in foreground
watch -n 15 "echo 'Capacity:' && \
  aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $ASG_NAME \
    --region $AWS_REGION \
    --query 'AutoScalingGroups[0].[DesiredCapacity]' \
    --output text && \
  echo '' && \
  echo 'CPU:' && \
  aws cloudwatch get-metric-statistics \
    --namespace AWS/EC2 \
    --metric-name CPUUtilization \
    --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
    --start-time \$(date -u -d '2 minutes ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time \$(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 60 \
    --statistics Average \
    --region $AWS_REGION \
    --query 'Datapoints[-1].Average' \
    --output text"
```

## Analyzing Results

### View Scaling History

```bash
# Get all scaling activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $ASG_NAME \
  --max-records 50 \
  --region $AWS_REGION \
  --query 'Activities[*].[StartTime,EndTime,StatusCode,Cause,Description]' \
  --output table > scaling-history.txt

cat scaling-history.txt
```

### Calculate Scaling Metrics

```bash
# Time to scale out
echo "Analyzing scale-out time..."
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $ASG_NAME \
  --region $AWS_REGION \
  --query 'Activities[?contains(Description, `Launching`)].{Start:StartTime,End:EndTime}' \
  --output table

# Instance launch success rate
TOTAL=$(aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $ASG_NAME \
  --region $AWS_REGION \
  --query 'length(Activities[?contains(Description, `Launching`)])' \
  --output text)

SUCCESSFUL=$(aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $ASG_NAME \
  --region $AWS_REGION \
  --query 'length(Activities[?contains(Description, `Launching`) && StatusCode==`Successful`])' \
  --output text)

echo "Launch success rate: $SUCCESSFUL/$TOTAL"
```

### Export Metrics to CSV

```bash
# Export CPU metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average,Maximum,Minimum \
  --region $AWS_REGION \
  --query 'Datapoints | sort_by(@, &Timestamp)[*].[Timestamp,Average,Maximum,Minimum]' \
  --output text | \
  awk 'BEGIN {print "Timestamp,Average,Maximum,Minimum"} {print $1","$2","$3","$4}' > cpu-metrics.csv

echo "Metrics exported to cpu-metrics.csv"
```

## Troubleshooting

**Issue:** Scaling not triggered
- Check CloudWatch alarms are in ALARM state
- Verify metrics are being published
- Review cooldown periods
- Check if scaling policies are enabled

**Issue:** Instances launch but immediately terminate
- Check health check grace period
- Verify user data script completes successfully
- Review instance logs

**Issue:** Load test fails
- Verify ALB DNS resolves
- Check security groups allow traffic
- Ensure target group has healthy targets

**Issue:** Slow scaling response
- Reduce cooldown periods
- Lower alarm thresholds
- Use step scaling for faster response

## Next Steps

Proceed to [Step 8: Monitor and Visualize](./08-monitoring.md)
