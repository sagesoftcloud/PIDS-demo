# PIDS-demo-jcc ASG - CREATED SUCCESSFULLY! ✅

**Created:** 2026-02-11 10:26 AM (Asia/Manila)  
**Account:** 192957544618  
**Region:** us-east-1  
**Profile:** kiro-cli

---

## 🎉 YOUR ALB URL (WORKING!)

```
http://PIDS-demo-jcc-alb-1821903953.us-east-1.elb.amazonaws.com
```

**Open this URL in your browser to see your Auto Scaling Group in action!**

---

## ✅ Resources Created

### 1. Security Groups
- **ALB Security Group:** sg-0074f4c81957d2242
  - Name: PIDS-demo-jcc-alb-sg
  - Allows: HTTP (80) from 0.0.0.0/0

- **Instance Security Group:** sg-076a2157e84e0c876
  - Name: PIDS-demo-jcc-instance-sg
  - Allows: HTTP (80) from ALB security group

### 2. Launch Template
- **ID:** lt-0b48e78d93d117533
- **Name:** PIDS-demo-jcc-template
- **Instance Type:** t3.micro
- **AMI:** ami-0453ec754f44f9a4a (Amazon Linux 2)
- **User Data:** Installs Apache and creates beautiful demo page

### 3. Target Group
- **ARN:** arn:aws:elasticloadbalancing:us-east-1:192957544618:targetgroup/PIDS-demo-jcc-tg/cb867917a5f8462a
- **Name:** PIDS-demo-jcc-tg
- **Protocol:** HTTP:80
- **Health Check:** / (every 30 seconds)

### 4. Application Load Balancer
- **ARN:** arn:aws:elasticloadbalancing:us-east-1:192957544618:loadbalancer/app/PIDS-demo-jcc-alb/f062f8dec7bd6e05
- **Name:** PIDS-demo-jcc-alb
- **DNS:** PIDS-demo-jcc-alb-1821903953.us-east-1.elb.amazonaws.com
- **Scheme:** Internet-facing
- **Subnets:** 
  - subnet-06d7f51e66a4b909a (us-east-1a)
  - subnet-0487da5b992c85857 (us-east-1b)

### 5. Auto Scaling Group
- **Name:** PIDS-demo-jcc-asg
- **ARN:** arn:aws:autoscaling:us-east-1:192957544618:autoScalingGroup:bf9c7d7c-eae6-4d88-8b5c-7783ede45b2d:autoScalingGroupName/PIDS-demo-jcc-asg
- **Configuration:**
  - Desired: 2
  - Minimum: 2
  - Maximum: 5
- **Health Check:** ELB (300s grace period)
- **Scaling Policy:** Target tracking - 50% CPU

### 6. EC2 Instances (Auto-Created)
- **Instance 1:** i-009b29f45e8bddb3e (us-east-1a) - InService, Healthy ✅
- **Instance 2:** i-04e2f477286809e9c (us-east-1b) - InService, Healthy ✅

### 7. CloudWatch Alarms (Auto-Created)
- **High CPU Alarm:** TargetTracking-PIDS-demo-jcc-asg-AlarmHigh-756f7e03-fde6-416e-bb5d-ac453ae10e8d
- **Low CPU Alarm:** TargetTracking-PIDS-demo-jcc-asg-AlarmLow-a92883b8-45e5-421c-9292-d30cb0c06bb4

---

## 🌐 What You'll See

When you open the ALB URL, you'll see:
- 🚀 Beautiful purple gradient page
- "PIDS Demo - JCC" title
- Instance ID (changes on refresh)
- Availability Zone (changes on refresh)
- "Auto Scaling Group is working!" message

**Try refreshing the page** - you'll see different instance IDs as the load balancer distributes traffic!

---

## 📊 Configuration Details

**VPC:** vpc-049501e2e003cb81b  
**Subnets:** 2 public subnets in different AZs  
**Instance Type:** t3.micro  
**Capacity:** Min: 2, Desired: 2, Max: 5  
**Scaling Trigger:** CPU > 50% (scale out), CPU < 50% (scale in)  
**Health Checks:** ELB health checks enabled  

---

## 💰 Cost Estimate

- **2 t3.micro instances:** ~$0.02/hour
- **Application Load Balancer:** ~$0.02/hour
- **Total:** ~$0.04/hour or ~$0.96/day

---

## 🧪 Testing

### Test Load Balancing
1. Open the ALB URL in your browser
2. Refresh multiple times
3. Watch the Instance ID change (load balancing working!)

### Test Auto Scaling
To trigger scaling, you would need to generate CPU load on the instances.
The ASG will automatically add instances (up to 5) when CPU exceeds 50%.

---

## 🧹 Cleanup Commands

When you're done, delete resources in this order:

```bash
# 1. Delete Auto Scaling Group
aws autoscaling delete-auto-scaling-group \
  --auto-scaling-group-name PIDS-demo-jcc-asg \
  --force-delete \
  --profile kiro-cli \
  --region us-east-1

# Wait 2 minutes for instances to terminate

# 2. Delete Load Balancer
aws elbv2 delete-load-balancer \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:192957544618:loadbalancer/app/PIDS-demo-jcc-alb/f062f8dec7bd6e05 \
  --profile kiro-cli \
  --region us-east-1

# 3. Delete Target Group
aws elbv2 delete-target-group \
  --target-group-arn arn:aws:elasticloadbalancing:us-east-1:192957544618:targetgroup/PIDS-demo-jcc-tg/cb867917a5f8462a \
  --profile kiro-cli \
  --region us-east-1

# 4. Delete Launch Template
aws ec2 delete-launch-template \
  --launch-template-id lt-0b48e78d93d117533 \
  --profile kiro-cli \
  --region us-east-1

# 5. Delete Security Groups
aws ec2 delete-security-group \
  --group-id sg-076a2157e84e0c876 \
  --profile kiro-cli \
  --region us-east-1

aws ec2 delete-security-group \
  --group-id sg-0074f4c81957d2242 \
  --profile kiro-cli \
  --region us-east-1
```

---

## ✅ Success!

Your Auto Scaling Group is now running and accessible at:

**http://PIDS-demo-jcc-alb-1821903953.us-east-1.elb.amazonaws.com**

Enjoy your demo! 🎉
