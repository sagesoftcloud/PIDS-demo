# Verification Checklist - PIDS-demo-jcc

Use this checklist to verify your Auto Scaling Group setup is complete and working.

## Pre-Setup Verification

- [ ] Logged into AWS account 192957544618
- [ ] Region set to us-east-1 (N. Virginia)
- [ ] VPC vpc-049501e2e003cb81b exists and is accessible

## Security Groups

- [ ] `PIDS-demo-jcc-alb-sg` created
  - [ ] Inbound: HTTP (80) from 0.0.0.0/0
  - [ ] VPC: vpc-049501e2e003cb81b
  
- [ ] `PIDS-demo-jcc-instance-sg` created
  - [ ] Inbound: HTTP (80) from ALB security group
  - [ ] Inbound: SSH (22) from My IP
  - [ ] VPC: vpc-049501e2e003cb81b

## Key Pair

- [ ] `PIDS-demo-jcc-key` created
- [ ] .pem file downloaded and saved securely

## Launch Template

- [ ] `PIDS-demo-jcc-template` created
- [ ] Instance type: t3.micro
- [ ] AMI: Amazon Linux 2
- [ ] Key pair: PIDS-demo-jcc-key
- [ ] Security group: PIDS-demo-jcc-instance-sg
- [ ] User data script added (HTML page with instance info)

## Target Group

- [ ] `PIDS-demo-jcc-tg` created
- [ ] Protocol: HTTP, Port: 80
- [ ] VPC: vpc-049501e2e003cb81b
- [ ] Health check path: /

## Application Load Balancer

- [ ] `PIDS-demo-jcc-alb` created
- [ ] Scheme: Internet-facing
- [ ] VPC: vpc-049501e2e003cb81b
- [ ] 2 public subnets selected (different AZs)
- [ ] Security group: PIDS-demo-jcc-alb-sg
- [ ] Listener: HTTP:80 → PIDS-demo-jcc-tg
- [ ] State: Active
- [ ] DNS name copied

## Auto Scaling Group

- [ ] `PIDS-demo-jcc-asg` created
- [ ] Launch template: PIDS-demo-jcc-template
- [ ] VPC: vpc-049501e2e003cb81b
- [ ] 2 public subnets selected
- [ ] Attached to target group: PIDS-demo-jcc-tg
- [ ] ELB health checks enabled
- [ ] Desired capacity: 2
- [ ] Minimum capacity: 2
- [ ] Maximum capacity: 5
- [ ] Scaling policy: CPU target 50%
- [ ] Tag: Name = PIDS-demo-jcc

## Instance Verification

- [ ] 2 instances launched
- [ ] Both instances show "InService" lifecycle
- [ ] Both instances show "Healthy" health status
- [ ] Instances are in different availability zones
- [ ] Instances have tag: Name = PIDS-demo-jcc

## Target Group Health

- [ ] Go to Target Groups → PIDS-demo-jcc-tg → Targets tab
- [ ] 2 targets registered
- [ ] Both targets show "healthy" status
- [ ] Health check status: 2/2 healthy

## Load Balancer Verification

- [ ] ALB state is "Active"
- [ ] ALB has 2 availability zones
- [ ] Target group shows 2 healthy targets
- [ ] DNS name is accessible

## Website Verification

- [ ] Open ALB DNS in browser
- [ ] Page loads successfully
- [ ] Shows "PIDS Demo - JCC" title
- [ ] Shows Instance ID
- [ ] Shows Availability Zone
- [ ] Shows "Auto Scaling Group is working!" message
- [ ] Refresh page multiple times
- [ ] Instance ID changes (load balancing working)
- [ ] AZ changes (multi-AZ working)

## Scaling Policy Verification

- [ ] Go to ASG → Automatic scaling tab
- [ ] Target tracking policy exists
- [ ] Policy name: cpu-policy
- [ ] Target: 50% CPU
- [ ] Scale out cooldown: 60 seconds
- [ ] Scale in cooldown: 300 seconds

## CloudWatch Verification (Optional)

- [ ] Go to CloudWatch → All metrics
- [ ] EC2 → By Auto Scaling Group
- [ ] Select PIDS-demo-jcc-asg
- [ ] CPUUtilization metric visible
- [ ] Data points showing

## Final Checks

- [ ] All resources in same VPC (vpc-049501e2e003cb81b)
- [ ] All resources in same region (us-east-1)
- [ ] Website accessible from internet
- [ ] Load balancing working (different instances respond)
- [ ] No errors in AWS Console
- [ ] ALB URL documented

## Success Criteria

✅ **Setup is successful if:**
1. ALB URL loads in browser
2. Beautiful purple page displays
3. Instance ID and AZ are shown
4. Refreshing shows different instances
5. 2 instances are healthy in target group
6. ASG shows 2/2 instances in service

## ALB URL

**Your ALB URL:**
```
http://_______________________________________________
```

**Date Completed:** _______________

**Time Taken:** _______________ minutes

---

## If Any Item Fails

1. Review the MANUAL_SETUP_GUIDE.md troubleshooting section
2. Check security group rules
3. Verify subnets are public
4. Check instance user data logs
5. Review Auto Scaling activity history

## Next Steps

After verification:
1. Test scaling by generating CPU load
2. Monitor CloudWatch metrics
3. Review Auto Scaling activity
4. When done, follow CLEANUP_STEPS.md
