# Your First AWS Auto Scaling Group - Beginner's Guide

Welcome to AWS! This guide will help you create your first Auto Scaling Group (ASG) - a system that automatically adds or removes servers based on traffic. Perfect for complete beginners!

**Time Required:** 45-60 minutes  
**Cost:** ~$0.10 for 2-hour test  
**Difficulty:** Beginner-friendly (no prior AWS experience needed)

---

## Before You Start

### What You'll Receive:
- AWS Account credentials (provided by instructor)
- Access to a pre-configured VPC: **myvpc-pids-demo-vpc**
- Web browser
- 45-60 minutes of focused time

### Important: Naming Convention
Throughout this guide, replace **yourname** with your actual name (lowercase, no spaces).

**Examples:**
- If your name is "John": `myasg-alb-sg-john`
- If your name is "Maria": `myasg-template-maria`
- If your name is "Alex": `myasg-group-alex`

### What You'll Learn:
- ✅ How to create web servers that scale automatically
- ✅ How load balancers distribute traffic
- ✅ How AWS monitors and responds to traffic changes
- ✅ Basic AWS security concepts

### What You'll Build:
- A website that automatically scales from 2 to 4 servers
- A load balancer that distributes visitor traffic
- Automatic monitoring and scaling based on CPU usage

---

## Step 1: Sign In to AWS Console (3 minutes)

**Note:** Your instructor will provide you with AWS account credentials.

1. Open your web browser
2. Go to https://console.aws.amazon.com
3. Click **Sign In**
4. Enter the credentials provided by your instructor:
   - **Account ID (12 digits):** _______________
   - **IAM user name:** _______________
   - **Password:** _______________
5. Click **Sign in**
6. You'll see the AWS Management Console homepage

**Tip:** Bookmark this page - you'll use it often!

**Write these down for reference:**
- Account ID: _______________
- Your IAM username: _______________

---

## Step 2: Select Your Region (2 minutes)

1. Look at the top-right corner of the console
2. Click the region dropdown (e.g., "N. Virginia")
3. Select **US East (N. Virginia)** or **us-east-1**
4. Keep this region for all steps

**Why?** All resources must be in the same region.

---

## Step 3: Verify Your VPC (3 minutes)

**Important Note:** You will be using a pre-configured VPC instead of creating a new one.

**VPC ID:** myvpc-pids-demo-vpc

### 3.1 Open VPC Service

1. Click the **search bar** at the top of the console
2. Type **VPC**
3. Click **VPC** from the results

### 3.2 Verify Your VPC

1. In the left menu, click **Your VPCs**
2. Look for VPC ID: **myvpc-pids-demo-vpc**
3. Verify it exists and note the **IPv4 CIDR** (should be something like 10.0.0.0/16)

### 3.3 Find Your Subnets

1. In the left menu, click **Subnets**
2. You'll see a list of subnets
3. Find **2 public subnets** that belong to VPC **myvpc-pids-demo-vpc**
4. Make sure they are in **different Availability Zones** (like us-east-1a and us-east-1b)

**Write these down:**
- VPC ID: myvpc-pids-demo-vpc
- Subnet 1 ID: _________________ (AZ: _______)
- Subnet 2 ID: _________________ (AZ: _______)

**What is a VPC?** Think of it as your private section of AWS where your servers will live.

**What is a Subnet?** A subdivision of your VPC in a specific data center location (Availability Zone).

---

## Step 4: Create Security Groups (10 minutes)

### 4.1 Create Load Balancer Security Group

1. In the left menu, click **Security Groups**
2. Click **Create security group**
3. Fill in:
   - **Security group name:** `myasg-alb-sg`
   - **Description:** `Load Balancer Security Group`
   - **VPC:** Select `myasg-vpc`
4. Under **Inbound rules**, click **Add rule**:
   - **Type:** `HTTP`
   - **Source:** `Anywhere-IPv4` (0.0.0.0/0)
5. Click **Create security group**

### 4.2 Create Instance Security Group

1. Click **Create security group** again
2. Fill in:
   - **Security group name:** `myasg-instance-sg`
   - **Description:** `Instance Security Group`
   - **VPC:** Select `myasg-vpc`
3. Under **Inbound rules**, click **Add rule** twice:
   
   **Rule 1:**
   - **Type:** `HTTP`
   - **Source:** `Custom`
   - In the search box, type `myasg-alb-sg` and select it
   
   **Rule 2:**
   - **Type:** `SSH`
   - **Source:** `My IP` (automatically detects your IP)
   
4. Click **Create security group**

**What you created:**
- Security group for load balancer (allows web traffic from internet)
- Security group for instances (allows traffic from load balancer only)

---

## Step 5: Create Key Pair (5 minutes)

1. In the search bar, type **EC2**
2. Click **EC2** to open EC2 Dashboard
3. In the left menu, scroll down to **Key Pairs**
4. Click **Create key pair**
5. Fill in:
   - **Name:** `myasg-key`
   - **Key pair type:** `RSA`
   - **Private key file format:** `.pem` (Mac/Linux/Windows)
   Note: Make sure you have your software to connect (putty or bitvise)
6. Click **Create key pair**
7. The key file will download automatically
8. **Save this file safely!** You'll need it to access your servers

---

## Step 6: Create Launch Template (15 minutes)

### 6.1 Start Creating Template

1. In EC2 Dashboard left menu, click **Launch Templates**
2. Click **Create launch template**

### 6.2 Fill Template Details

**Template name and description:**
- **Launch template name:** `myasg-template-yourname`
- **Template version description:** `Version 1`

**Application and OS Images (Amazon Machine Image):**
- Click **Quick Start**
- Select **Amazon Linux**
- Choose **Amazon Linux 2 AMI** (free tier eligible)

**Instance type:**
- Select **t3.micro** (or t2.micro if t3 not available)

**Key pair:**
- Select `myasg-key-yourname` (the one you just created)

**Network settings:**
- **Subnet:** Don't include in launch template
- **Firewall (security groups):** Select existing security group
- Choose `myasg-instance-sg`

**Advanced details:**
- Scroll down to **User data** (at the bottom)
- Copy and paste this script:

```bash
#!/bin/bash
yum update -y
yum install -y httpd

INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
AZ=$(ec2-metadata --availability-zone | cut -d " " -f 2)

cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Auto Scaling Demo</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: rgba(255, 255, 255, 0.95);
            padding: 40px;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 600px;
            width: 100%;
        }
        h1 {
            color: #667eea;
            margin-bottom: 30px;
            font-size: 2.5em;
            text-align: center;
        }
        .info-box {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 10px;
            margin: 15px 0;
        }
        .info-row {
            display: flex;
            justify-content: space-between;
            padding: 10px 0;
            border-bottom: 1px solid rgba(255,255,255,0.2);
        }
        .info-row:last-child { border-bottom: none; }
        .label { font-weight: bold; }
        .value { font-family: monospace; }
        .status {
            text-align: center;
            margin-top: 20px;
            font-size: 1.2em;
            color: #28a745;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            color: #666;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Auto Scaling Demo</h1>
        <div class="info-box">
            <div class="info-row">
                <span class="label">Instance ID:</span>
                <span class="value">INSTANCE_ID_PLACEHOLDER</span>
            </div>
            <div class="info-row">
                <span class="label">Availability Zone:</span>
                <span class="value">AZ_PLACEHOLDER</span>
            </div>
            <div class="info-row">
                <span class="label">Server Status:</span>
                <span class="value">✅ Running</span>
            </div>
        </div>
        <div class="status">
            Server is healthy and ready!
        </div>
        <div class="footer">
            Refresh this page to see different servers respond<br>
            as the Auto Scaling Group distributes traffic
        </div>
    </div>
</body>
</html>
HTML

sed -i "s/INSTANCE_ID_PLACEHOLDER/$INSTANCE_ID/g" /var/www/html/index.html
sed -i "s/AZ_PLACEHOLDER/$AZ/g" /var/www/html/index.html

systemctl start httpd
systemctl enable httpd
```

### 6.3 Create Template

1. Click **Create launch template** (bottom right)
2. You'll see a success message
3. Click **View launch templates**

**What you created:**
- A template that defines how your web servers will be configured
- Includes a beautiful sample website

---

## Step 7: Create Target Group (5 minutes)

1. In the left menu, scroll to **Load Balancing**
2. Click **Target Groups**
3. Click **Create target group**
4. Fill in:
   - **Choose a target type:** `Instances`
   - **Target group name:** `myasg-tg-yourname`
   - **Protocol:** `HTTP`
   - **Port:** `80`
   - **VPC:** Select `myvpc-pids-demo-vpc`
   - **Health check path:** `/`
5. Click **Next**
6. **Don't register any targets** (Auto Scaling will do this)
7. Click **Create target group**

**What you created:**
- A target group that the load balancer will use to route traffic

---

## Step 8: Create Load Balancer (10 minutes)

### 8.1 Start Creating Load Balancer

1. In the left menu, click **Load Balancers**
2. Click **Create load balancer**
3. Select **Application Load Balancer**
4. Click **Create**

### 8.2 Configure Load Balancer

**Basic configuration:**
- **Load balancer name:** `myasg-alb-yourname`
- **Scheme:** `Internet-facing`
- **IP address type:** `IPv4`

**Network mapping:**
- **VPC:** Select `myasg-vpc`
- **Mappings:** Check both availability zones
  - Select the public subnet for each AZ

**Security groups:**
- Remove the default security group
- Select `myasg-alb-sg`

**Listeners and routing:**
- **Protocol:** `HTTP`
- **Port:** `80`
- **Default action:** Select `myasg-tg`

### 8.3 Create Load Balancer

1. Click **Create load balancer** (bottom right)
2. You'll see a success message
3. Click **View load balancer**
4. Wait 2-3 minutes for **State** to change from "Provisioning" to "Active"
5. **Copy the DNS name** (looks like: myasg-alb-1234567890.us-east-1.elb.amazonaws.com)
6. **Save this URL** - this is your website address!

**What you created:**
- A load balancer that distributes traffic across your web servers

---

## Step 9: Create Auto Scaling Group (15 minutes)

### 9.1 Start Creating Auto Scaling Group

1. In the left menu, scroll to **Auto Scaling**
2. Click **Auto Scaling Groups**
3. Click **Create Auto Scaling group**

### 9.2 Step 1: Choose launch template

- **Auto Scaling group name:** `myasg-group`
- **Launch template:** Select `myasg-template`
- Click **Next**

### 9.3 Step 2: Choose instance launch options

- **VPC:** Select `myasg-vpc`
- **Availability Zones and subnets:** Select both public subnets
- Click **Next**

### 9.4 Step 3: Configure advanced options

- **Load balancing:** Select `Attach to an existing load balancer`
- **Choose from your load balancer target groups:** Select `myasg-tg`
- **Health checks:**
  - Check `Turn on Elastic Load Balancing health checks`
  - **Health check grace period:** `300` seconds
- Click **Next**

### 9.5 Step 4: Configure group size and scaling

**Group size:**
- **Desired capacity:** `2`
- **Minimum capacity:** `1`
- **Maximum capacity:** `4`

**Scaling policies:**
- Select `Target tracking scaling policy`
- **Scaling policy name:** `cpu-policy`
- **Metric type:** `Average CPU utilization`
- **Target value:** `50`

Click **Next**

### 9.6 Step 5: Add notifications

- Skip this step
- Click **Next**

### 9.7 Step 6: Add tags

- Click **Add tag**
- **Key:** `Name`
- **Value:** `myasg-instance`
- Click **Next**

### 9.8 Step 7: Review

- Review all settings
- Click **Create Auto Scaling group**

**What you created:**
- An Auto Scaling Group that maintains 2 instances
- Will scale up to 4 instances if CPU > 50%
- Will scale down to 1 instance if CPU < 50%

---

## Step 10: Wait for Instances to Launch (5 minutes)

### 10.1 Check Auto Scaling Group

1. You're now on the Auto Scaling Groups page
2. Click on `myasg-group`
3. Click the **Instance management** tab
4. You should see 2 instances
5. Wait until **Lifecycle** shows "InService" for both
6. Wait until **Health status** shows "Healthy" for both
7. This takes 3-5 minutes

### 10.2 Check Target Group Health

1. Go back to **Target Groups** (left menu under Load Balancing)
2. Click `myasg-tg`
3. Click the **Targets** tab
4. You should see 2 targets
5. Wait until **Health status** shows "healthy" for both

---

## Step 11: Test Your Website (5 minutes)

### 11.1 Access Your Website

1. Open a new browser tab
2. Paste the Load Balancer DNS name you saved earlier
3. Example: `http://myasg-alb-1234567890.us-east-1.elb.amazonaws.com`
4. You should see your beautiful website!

### 11.2 See Different Instances

1. Refresh the page multiple times (press F5)
2. Notice the **Instance ID** and **Availability Zone** change
3. This shows the load balancer distributing traffic!

**Congratulations!** Your auto-scaling website is working! 🎉

---

## Step 12: Test Auto Scaling (Optional - 15 minutes)

### 12.1 Generate Load

To see auto scaling in action, you need to generate high CPU load.

**Option 1: Use a load testing website**
1. Go to https://loader.io (free account)
2. Create a test targeting your ALB DNS
3. Run the test for 5 minutes

**Option 2: Manual method**
1. Go to **EC2 Dashboard**
2. Click **Instances**
3. Select one of your instances
4. Click **Connect to the EC2**
5. In the terminal, run: `stress --cpu 4 --timeout 300s`

### 12.2 Watch Scaling Happen

1. Go to **Auto Scaling Groups**
2. Click `myasg-group-yourname`
3. Click the **Activity** tab
4. Refresh every 30 seconds
5. After 2-3 minutes, you'll see "Launching a new EC2 instance"
6. The **Desired capacity** will increase from 2 to 3 or 4

### 12.3 Monitor Metrics

1. Click the **Monitoring** tab
2. You'll see graphs for:
   - CPU Utilization (should be high)
   - Number of instances (should increase)

---

## Step 13: View Scaling Activities (5 minutes)

### See What Happened

1. In your Auto Scaling Group, click the **Activity** tab
2. Click the **Activity history** section
3. You'll see entries like:
   - "Launching a new EC2 instance: i-xxxxx"
   - "Terminating EC2 instance: i-xxxxx"
4. Each entry shows when and why scaling happened

### View CloudWatch Metrics

1. In the search bar, type **CloudWatch**
2. Click **CloudWatch**
3. Click **All metrics** (left menu)
4. Click **EC2**
5. Click **By Auto Scaling Group**
6. Check the box next to **CPUUtilization** for your group
7. You'll see a graph of CPU usage over time

---

## Step 14: Cleanup (10 minutes)

**Important:** Delete everything to avoid charges!

### 14.1 Delete Auto Scaling Group

1. Go to **EC2** → **Auto Scaling Groups**
2. Select `myasg-group`
3. Click **Actions** → **Delete**
4. Type `delete` to confirm
5. Click **Delete**
6. Wait 2-3 minutes for instances to terminate

### 14.2 Delete Load Balancer

1. Go to **Load Balancers**
2. Select `myasg-alb`
3. Click **Actions** → **Delete load balancer**
4. Type `confirm` and click **Delete**

### 14.3 Delete Target Group

1. Go to **Target Groups**
2. Select `myasg-tg`
3. Click **Actions** → **Delete**
4. Click **Yes, delete**

### 14.4 Delete Launch Template

1. Go to **Launch Templates**
2. Select `myasg-template`
3. Click **Actions** → **Delete template**
4. Type `Delete` and click **Delete**

### 14.5 Delete Security Groups

1. Go to **Security Groups**
2. Select `myasg-instance-sg`
3. Click **Actions** → **Delete security groups**
4. Click **Delete**
5. Repeat for `myasg-alb-sg`

### 14.6 Delete VPC

1. In the search bar, type **VPC**
2. Click **Your VPCs**
3. Select `myasg-vpc`
4. Click **Actions** → **Delete VPC**
5. Type `delete` to confirm
6. Click **Delete**
7. This deletes the VPC, subnets, route tables, and internet gateway

### 14.7 Delete Key Pair

1. Go to **EC2** → **Key Pairs**
2. Select `myasg-key`
3. Click **Actions** → **Delete**
4. Type `Delete` and click **Delete**

**All done!** Everything is cleaned up. ✅

---

## Understanding What You Built

### The Architecture

```
Internet Users
      ↓
Load Balancer (distributes traffic)
      ↓
Target Group (tracks healthy servers)
      ↓
Auto Scaling Group (manages servers)
      ↓
Web Servers (2-4 instances)
```

### How Auto Scaling Works

1. **Normal Load:** 2 servers running (desired capacity)
2. **High Load:** CPU goes above 50%
3. **Scale Out:** Auto Scaling launches more servers (up to 4)
4. **Load Distributed:** Load balancer spreads traffic across all servers
5. **Low Load:** CPU drops below 50%
6. **Scale In:** Auto Scaling terminates extra servers (down to 1)

### Key Concepts

- **VPC:** Your private network in AWS
- **Subnet:** A section of your VPC in a specific availability zone
- **Security Group:** Firewall rules for your resources
- **Load Balancer:** Distributes traffic across multiple servers
- **Target Group:** Defines which servers receive traffic
- **Launch Template:** Blueprint for creating servers
- **Auto Scaling Group:** Automatically adds/removes servers based on demand

---

## Troubleshooting

### Website not loading?

**Check 1: Is the load balancer active?**
1. Go to **Load Balancers**
2. Check if **State** is "Active" (not "Provisioning")
3. Wait if still provisioning

**Check 2: Are targets healthy?**
1. Go to **Target Groups** → `myasg-tg` → **Targets** tab
2. Check if **Health status** is "healthy"
3. If "unhealthy", wait 5 minutes and refresh

**Check 3: Are instances running?**
1. Go to **EC2** → **Instances**
2. Check if instances are in "running" state
3. Check if **Status check** shows "2/2 checks passed"

### Instances not launching?

**Check 1: View Auto Scaling activities**
1. Go to **Auto Scaling Groups** → `myasg-group`
2. Click **Activity** tab
3. Look for error messages

**Check 2: Check service limits**
1. You might have reached your EC2 instance limit
2. Go to **Service Quotas** in the search bar
3. Search for "Running On-Demand Standard instances"
4. Request an increase if needed

### Scaling not happening?

**Check 1: Generate enough load**
- CPU must stay above 50% for 2-3 minutes
- One instance under load might not be enough

**Check 2: Check CloudWatch metrics**
1. Go to **CloudWatch** → **All metrics**
2. Check if CPU metrics are being reported

---

## Cost Breakdown

### What You'll Pay

- **EC2 Instances (t3.micro):** $0.0104/hour × 2 = $0.0208/hour
- **Load Balancer:** $0.0225/hour
- **Data Transfer:** ~$0.001/hour (minimal for testing)

**Total:** ~$0.044/hour or **$0.09 for 2-hour test**

### How to Minimize Costs

1. ✅ Run cleanup immediately after testing
2. ✅ Use t3.micro instances (cheapest)
3. ✅ Test during off-peak hours
4. ✅ Set billing alerts (see next section)

---

## Setting Up Billing Alerts (Recommended)

### Create a Budget Alert

1. In the search bar, type **Billing**
2. Click **Billing and Cost Management**
3. Click **Budgets** (left menu)
4. Click **Create budget**
5. Select **Customize (advanced)**
6. Choose **Cost budget**
7. Set **Budgeted amount:** `$5`
8. Set **Alert threshold:** `80%` (alert at $4)
9. Enter your email
10. Click **Create budget**

You'll get an email if costs exceed $4!

---

## Next Steps

### Learn More

- **AWS Free Tier:** https://aws.amazon.com/free/
- **Auto Scaling Documentation:** https://docs.aws.amazon.com/autoscaling/
- **EC2 Tutorial:** https://aws.amazon.com/ec2/getting-started/

### Try These Experiments

1. **Change the scaling threshold** to 30% CPU
2. **Increase max capacity** to 6 instances
3. **Add scheduled scaling** for specific times
4. **Try different instance types** (t3.small, t3.nano)
5. **Add HTTPS** with a free SSL certificate

---

## Summary

You successfully created:
- ✅ A VPC with networking
- ✅ Security groups for protection
- ✅ A load balancer to distribute traffic
- ✅ An Auto Scaling Group with 2-4 instances
- ✅ A beautiful sample website
- ✅ Automatic scaling based on CPU usage

**Time spent:** 60-90 minutes  
**Cost:** ~$0.10 for testing  
**Skills learned:** AWS fundamentals, auto scaling, load balancing

**Congratulations on completing your first AWS Auto Scaling setup!** 🎉

---

## Quick Reference

### Your Resources

- **Website URL:** Your Load Balancer DNS name
- **VPC:** myasg-vpc
- **Load Balancer:** myasg-alb
- **Auto Scaling Group:** myasg-group
- **Min instances:** 1
- **Max instances:** 4
- **Scaling trigger:** 50% CPU

### Important Pages

- **EC2 Dashboard:** See all instances
- **Auto Scaling Groups:** Monitor scaling
- **Load Balancers:** Check load balancer status
- **CloudWatch:** View metrics and graphs

### Remember

- ⚠️ Always run cleanup after testing
- 💰 Set up billing alerts
- 📧 Check your email for AWS notifications
- 🔒 Keep your key pair file safe
