#!/bin/bash

# Auto Scaling Group Demo - Real-time Monitor

source ~/asg-demo-config.sh

ALB_FULL_NAME=$(echo $ALB_ARN | cut -d':' -f6 | cut -d'/' -f2-4)

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
  
  echo "Min: $(echo $ASG_INFO | awk '{print $1}') | Desired: $(echo $ASG_INFO | awk '{print $2}') | Max: $(echo $ASG_INFO | awk '{print $3}')"
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
    --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
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
  
  if [ "$CPU" != "None" ] && [ -n "$CPU" ]; then
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
  
  if [ "$REQUESTS" != "None" ] && [ -n "$REQUESTS" ]; then
    printf "Requests: %.0f\n" $REQUESTS
  else
    echo "Requests: 0"
  fi
  
  echo ""
  echo "Application URL: http://$ALB_DNS"
  echo ""
  echo "Press Ctrl+C to exit"
  
  sleep 10
done
