#!/bin/bash

# Auto Scaling Group Demo - Stress Test Script

source ~/asg-demo-config.sh

echo "=========================================="
echo "  Auto Scaling Group Stress Test"
echo "=========================================="
echo ""

# Check if hey is installed
if ! command -v hey &> /dev/null; then
    echo "Error: 'hey' is not installed"
    echo "Install with: brew install hey (macOS) or download from https://github.com/rakyll/hey"
    exit 1
fi

echo "Target: http://$ALB_DNS"
echo ""
echo "Select stress test type:"
echo "1) CPU Stress (trigger CPU-based scaling)"
echo "2) Light Load Test (100 req/s for 2 minutes)"
echo "3) Medium Load Test (500 req/s for 5 minutes)"
echo "4) Heavy Load Test (1000 req/s for 10 minutes)"
echo "5) Spike Test (sudden traffic spike)"
echo "6) Comprehensive Test (all phases)"
echo ""
read -p "Enter choice [1-6]: " choice

case $choice in
  1)
    echo ""
    echo "Starting CPU stress on all instances..."
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
      
      echo "Stressing $INSTANCE_ID ($PUBLIC_IP)"
      curl -X POST http://$PUBLIC_IP/stress/start 2>/dev/null
    done
    
    echo ""
    echo "CPU stress started on all instances (5 minutes duration)"
    echo "Monitor with: ./scripts/monitor.sh"
    ;;
    
  2)
    echo ""
    echo "Starting light load test..."
    hey -z 2m -q 100 -c 20 http://$ALB_DNS/
    ;;
    
  3)
    echo ""
    echo "Starting medium load test..."
    hey -z 5m -q 500 -c 50 http://$ALB_DNS/
    ;;
    
  4)
    echo ""
    echo "Starting heavy load test..."
    hey -z 10m -q 1000 -c 100 http://$ALB_DNS/
    ;;
    
  5)
    echo ""
    echo "Starting spike test..."
    echo "Phase 1: Baseline (30s)"
    hey -z 30s -c 10 http://$ALB_DNS/ > /dev/null 2>&1
    
    echo "Phase 2: SPIKE! (60s)"
    hey -z 60s -c 200 http://$ALB_DNS/
    
    echo "Phase 3: Sustained (2m)"
    hey -z 2m -c 50 http://$ALB_DNS/
    ;;
    
  6)
    echo ""
    echo "Starting comprehensive test..."
    
    echo "Phase 1: Warm-up (1m)"
    hey -z 1m -c 10 -q 10 http://$ALB_DNS/ > /dev/null 2>&1
    sleep 30
    
    echo "Phase 2: Gradual increase (3m)"
    hey -z 1m -c 20 -q 20 http://$ALB_DNS/ > /dev/null 2>&1 &
    sleep 60
    hey -z 1m -c 40 -q 40 http://$ALB_DNS/ > /dev/null 2>&1 &
    sleep 60
    hey -z 1m -c 60 -q 60 http://$ALB_DNS/ > /dev/null 2>&1 &
    wait
    sleep 30
    
    echo "Phase 3: Peak load (5m)"
    hey -z 5m -c 100 -q 100 http://$ALB_DNS/
    sleep 30
    
    echo "Phase 4: Cool down (2m)"
    hey -z 2m -c 20 -q 20 http://$ALB_DNS/ > /dev/null 2>&1
    
    echo ""
    echo "Comprehensive test complete!"
    ;;
    
  *)
    echo "Invalid choice"
    exit 1
    ;;
esac

echo ""
echo "=========================================="
echo "  Test Complete"
echo "=========================================="
echo ""
echo "View scaling activities:"
echo "aws autoscaling describe-scaling-activities --auto-scaling-group-name $ASG_NAME --region $AWS_REGION --max-records 10"
echo ""
echo "Monitor in real-time:"
echo "./scripts/monitor.sh"
