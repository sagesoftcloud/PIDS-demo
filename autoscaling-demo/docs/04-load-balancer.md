# Step 4: Create Application Load Balancer

Create an Application Load Balancer to distribute traffic across Auto Scaling Group instances.

## Overview

Components we'll create:
- Application Load Balancer (ALB)
- Target Group
- Listener
- Health checks

## Why Application Load Balancer?

- Layer 7 (HTTP/HTTPS) load balancing
- Path-based and host-based routing
- WebSocket support
- Integration with Auto Scaling Groups
- Health checks for automatic failover

## Step-by-Step Instructions

### 1. Load Configuration

```bash
source ~/asg-demo-config.sh
```

### 2. Create Target Group

Target group defines how the ALB routes requests to instances.

```bash
# Create target group
TG_ARN=$(aws elbv2 create-target-group \
  --name asg-demo-tg \
  --protocol HTTP \
  --port 80 \
  --vpc-id $VPC_ID \
  --health-check-enabled \
  --health-check-protocol HTTP \
  --health-check-path /health.html \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --region $AWS_REGION \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

echo "Target Group ARN: $TG_ARN"

# Add tags
aws elbv2 add-tags \
  --resource-arns $TG_ARN \
  --tags Key=Name,Value=asg-demo-tg \
  --region $AWS_REGION
```

### 3. Create Application Load Balancer

```bash
# Create ALB
ALB_ARN=$(aws elbv2 create-load-balancer \
  --name asg-demo-alb \
  --subnets $SUBNET1_ID $SUBNET2_ID \
  --security-groups $ALB_SG_ID \
  --scheme internet-facing \
  --type application \
  --ip-address-type ipv4 \
  --region $AWS_REGION \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

echo "ALB ARN: $ALB_ARN"

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns $ALB_ARN \
  --region $AWS_REGION \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

echo "ALB DNS Name: $ALB_DNS"

# Add tags
aws elbv2 add-tags \
  --resource-arns $ALB_ARN \
  --tags Key=Name,Value=asg-demo-alb \
  --region $AWS_REGION
```

### 4. Create Listener

Listener checks for connection requests and forwards them to target group.

```bash
# Create HTTP listener
LISTENER_ARN=$(aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN \
  --region $AWS_REGION \
  --query 'Listeners[0].ListenerArn' \
  --output text)

echo "Listener ARN: $LISTENER_ARN"
```

### 5. Configure Target Group Attributes

```bash
# Enable stickiness (optional - helps with demo visualization)
aws elbv2 modify-target-group-attributes \
  --target-group-arn $TG_ARN \
  --attributes \
    Key=stickiness.enabled,Value=false \
    Key=deregistration_delay.timeout_seconds,Value=30 \
    Key=load_balancing.algorithm.type,Value=round_robin \
  --region $AWS_REGION

echo "Target group attributes configured"
```

### 6. Wait for ALB to be Active

```bash
echo "Waiting for ALB to become active (this may take 2-3 minutes)..."

while true; do
  STATE=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --region $AWS_REGION \
    --query 'LoadBalancers[0].State.Code' \
    --output text)
  
  if [ "$STATE" == "active" ]; then
    echo "ALB is now active!"
    break
  fi
  
  echo "Current state: $STATE"
  sleep 10
done
```

### 7. Update Configuration

```bash
cat >> ~/asg-demo-config.sh << EOF
export TG_ARN=$TG_ARN
export ALB_ARN=$ALB_ARN
export ALB_DNS=$ALB_DNS
export LISTENER_ARN=$LISTENER_ARN
EOF

echo "Configuration updated"
echo ""
echo "=========================================="
echo "ALB DNS Name: $ALB_DNS"
echo "=========================================="
echo ""
echo "Save this DNS name - you'll use it to access your application"
```

## Health Check Configuration Explained

| Parameter | Value | Purpose |
|-----------|-------|---------|
| Path | /health.html | Endpoint to check |
| Interval | 30 seconds | How often to check |
| Timeout | 5 seconds | Max wait time |
| Healthy threshold | 2 | Consecutive successes needed |
| Unhealthy threshold | 3 | Consecutive failures needed |

**Health check logic:**
- Instance must pass 2 consecutive checks to be "healthy"
- Instance must fail 3 consecutive checks to be "unhealthy"
- Unhealthy instances are removed from rotation

## Load Balancing Algorithm

**Round Robin** (default):
- Distributes requests evenly across all healthy targets
- Each target receives equal number of requests
- Good for instances with similar capacity

**Least Outstanding Requests** (alternative):
- Routes to target with fewest pending requests
- Better for varying request processing times

To change algorithm:
```bash
aws elbv2 modify-target-group-attributes \
  --target-group-arn $TG_ARN \
  --attributes Key=load_balancing.algorithm.type,Value=least_outstanding_requests \
  --region $AWS_REGION
```

## Verification

```bash
# Check ALB status
aws elbv2 describe-load-balancers \
  --load-balancer-arns $ALB_ARN \
  --region $AWS_REGION

# Check target group
aws elbv2 describe-target-groups \
  --target-group-arns $TG_ARN \
  --region $AWS_REGION

# Check listener
aws elbv2 describe-listeners \
  --listener-arns $LISTENER_ARN \
  --region $AWS_REGION

# Check target health (will be empty until ASG is created)
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region $AWS_REGION
```

## Testing ALB (After ASG Creation)

Once you create the Auto Scaling Group in the next step:

```bash
# Test ALB endpoint
curl http://$ALB_DNS

# Test health check endpoint
curl http://$ALB_DNS/health.html

# Test multiple times to see different instances
for i in {1..10}; do
  curl -s http://$ALB_DNS | grep "Instance ID"
  sleep 1
done
```

## Advanced: Adding HTTPS Listener

If you have an SSL certificate in ACM:

```bash
# Get certificate ARN
CERT_ARN="arn:aws:acm:region:account-id:certificate/certificate-id"

# Create HTTPS listener
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTPS \
  --port 443 \
  --certificates CertificateArn=$CERT_ARN \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN \
  --region $AWS_REGION

# Redirect HTTP to HTTPS
aws elbv2 modify-listener \
  --listener-arn $LISTENER_ARN \
  --default-actions Type=redirect,RedirectConfig="{Protocol=HTTPS,Port=443,StatusCode=HTTP_301}" \
  --region $AWS_REGION
```

## Advanced: Path-Based Routing

Route different paths to different target groups:

```bash
# Create rule for /api/* path
aws elbv2 create-rule \
  --listener-arn $LISTENER_ARN \
  --priority 10 \
  --conditions Field=path-pattern,Values='/api/*' \
  --actions Type=forward,TargetGroupArn=$API_TG_ARN \
  --region $AWS_REGION
```

## Monitoring ALB

```bash
# View ALB metrics in CloudWatch
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=app/asg-demo-alb/$(echo $ALB_ARN | cut -d'/' -f3-4) \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum \
  --region $AWS_REGION
```

## Troubleshooting

**Issue:** ALB stuck in "provisioning" state
- Wait 3-5 minutes
- Check if subnets are in different AZs
- Verify security group exists

**Issue:** Cannot access ALB DNS
- Verify ALB state is "active"
- Check security group allows port 80 from 0.0.0.0/0
- Ensure subnets have internet gateway route

**Issue:** All targets unhealthy
- Check target group health check path exists
- Verify instance security group allows traffic from ALB
- Review instance logs for errors

**Issue:** 503 Service Unavailable
- No healthy targets in target group
- Auto Scaling Group hasn't launched instances yet
- Health checks are failing

## Next Steps

Proceed to [Step 5: Create Auto Scaling Group](./05-autoscaling-group.md)
