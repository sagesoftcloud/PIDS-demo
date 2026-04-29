# PIDS Demo JCC - Activity Documentation

This folder contains the manual setup guide for creating an Auto Scaling Group in AWS account 192957544618.

## Quick Reference

**Account:** 192957544618  
**VPC:** vpc-049501e2e003cb81b  
**Name:** PIDS-demo-jcc  
**Capacity:** Min: 2, Desired: 2, Max: 5

## Files

- `MANUAL_SETUP_GUIDE.md` - Complete step-by-step instructions
- `VERIFICATION_CHECKLIST.md` - Checklist to verify setup
- `CLEANUP_STEPS.md` - How to delete all resources

## Setup Time

Total: ~45 minutes
- Security Groups: 5 min
- Key Pair: 2 min
- Launch Template: 10 min
- Target Group: 5 min
- Load Balancer: 10 min
- Auto Scaling Group: 10 min
- Verification: 5 min

## What You'll Get

After following the guide, you'll have:
- A working Auto Scaling Group with 2 instances
- An Application Load Balancer distributing traffic
- A beautiful web page showing which instance is responding
- Automatic scaling based on CPU usage (50% target)

## ALB URL

After setup, your ALB URL will look like:
```
http://PIDS-demo-jcc-alb-XXXXXXXXX.us-east-1.elb.amazonaws.com
```

The exact URL will be provided in the AWS Console after the ALB is created.

## Important Notes

⚠️ **Use Public Subnets Only** - Make sure to select public subnets when creating the ASG

⚠️ **Wait for Health Checks** - It takes 3-5 minutes for instances to become healthy

⚠️ **Save the Key Pair** - Download and save the .pem file securely

⚠️ **Cleanup After Testing** - Follow cleanup steps to avoid ongoing charges

## Support

If you encounter issues:
1. Check the Troubleshooting section in MANUAL_SETUP_GUIDE.md
2. Verify all resources are in the same VPC
3. Ensure security groups allow proper traffic flow
4. Check CloudWatch logs for instance errors

## Cost Estimate

- 2 t3.micro instances: ~$0.02/hour
- Application Load Balancer: ~$0.02/hour
- **Total: ~$0.04/hour or $0.96/day**

Always cleanup after testing!
