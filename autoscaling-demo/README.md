# AWS Auto Scaling Group - Beginner's Workshop

Welcome to the AWS Auto Scaling Group hands-on workshop! This guide will help you create your first auto-scaling infrastructure on AWS.

## Overview

In this workshop, you will learn how to:
- Create an Application Load Balancer
- Configure security groups for secure access
- Set up a Launch Template for EC2 instances
- Create an Auto Scaling Group that scales from 2 to 4 instances
- Monitor and test automatic scaling based on CPU usage

## Prerequisites

- AWS account credentials (provided by instructor)
- Access to pre-configured VPC: `myvpc-pids-demo-vpc`
- Web browser
- 45-60 minutes of focused time

## Getting Started

Follow the step-by-step instructions in the **CONSOLE_SETUP_GUIDE.md** file.

The guide includes:
1. Signing in to AWS Console
2. Verifying your VPC and subnets
3. Creating security groups
4. Setting up a key pair
5. Creating a launch template
6. Configuring target groups and load balancer
7. Creating and testing your Auto Scaling Group
8. Cleanup instructions

## Important Notes

### Naming Convention
All resources must follow this naming pattern: `myasg-[resource]-yourname`

Replace `yourname` with your actual name (lowercase, no spaces).

**Examples:**
- `myasg-alb-sg-john`
- `myasg-template-maria`
- `myasg-group-alex`

### Cost Management
- This demo costs approximately **$0.10 for 2 hours**
- **Always complete the cleanup steps** at the end to avoid ongoing charges
- Delete all resources in the correct order as specified in the guide

### VPC Information
You will be using a pre-configured VPC instead of creating a new one:
- **VPC Name:** `myvpc-pids-demo-vpc`
- The VPC already has 2 public subnets in different availability zones

## Workshop Duration

- **Setup Time:** 45-60 minutes
- **Testing Time:** 15 minutes (optional)
- **Cleanup Time:** 10 minutes

## Support

If you encounter any issues during the workshop:
1. Review the troubleshooting section in the guide
2. Ask your instructor for assistance
3. Verify all naming conventions are correct
4. Ensure you selected the correct VPC and region

## What You'll Build

By the end of this workshop, you will have created:
- ✅ A load balancer that distributes traffic across multiple servers
- ✅ An Auto Scaling Group that automatically adds/removes servers based on demand
- ✅ Security groups that protect your infrastructure
- ✅ A beautiful sample website that shows which server is responding

## Challenge

After completing the basic setup, try the challenge section at the end of the guide to test your understanding of Auto Scaling concepts!

---

**Ready to start?** Open **CONSOLE_SETUP_GUIDE.md** and begin your AWS journey!
