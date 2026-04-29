# ASG Manual Setup - PIDS-demo-jcc

**Account ID:** 192957544618  
**VPC:** vpc-049501e2e003cb81b  
**Instance Name:** PIDS-demo-jcc  
**Configuration:**
- Desired: 2
- Minimum: 2
- Maximum: 5
- Subnets: Public subnets only

---

## Step 1: Create Security Groups (5 minutes)

### 1.1 Create ALB Security Group

1. Go to **EC2** → **Security Groups**
2. Click **Create security group**
3. Fill in:
   - **Name:** `PIDS-demo-jcc-alb-sg`
   - **Description:** `Load Balancer Security Group for PIDS demo`
   - **VPC:** `vpc-049501e2e003cb81b`
4. **Inbound rules:**
   - Type: HTTP, Port: 80, Source: 0.0.0.0/0
5. Click **Create security group**

### 1.2 Create Instance Security Group

1. Click **Create security group**
2. Fill in:
   - **Name:** `PIDS-demo-jcc-instance-sg`
   - **Description:** `Instance Security Group for PIDS demo`
   - **VPC:** `vpc-049501e2e003cb81b`
3. **Inbound rules:**
   - Rule 1: Type: HTTP, Port: 80, Source: Custom → Select `PIDS-demo-jcc-alb-sg`
   - Rule 2: Type: SSH, Port: 22, Source: My IP
4. Click **Create security group**

---

## Step 2: Create Key Pair (2 minutes)

1. Go to **EC2** → **Key Pairs**
2. Click **Create key pair**
3. Fill in:
   - **Name:** `PIDS-demo-jcc-key`
   - **Type:** RSA
   - **Format:** .pem
4. Click **Create key pair**
5. Save the downloaded file securely

---

## Step 3: Create Launch Template (10 minutes)

1. Go to **EC2** → **Launch Templates**
2. Click **Create launch template**
3. Fill in:

**Template name:** `PIDS-demo-jcc-template`

**Application and OS Images:**
- Quick Start: Amazon Linux
- AMI: Amazon Linux 2 AMI (HVM)

**Instance type:** t3.micro

**Key pair:** `PIDS-demo-jcc-key`

**Network settings:**
- Subnet: Don't include in launch template
- Security groups: `PIDS-demo-jcc-instance-sg`

**Advanced details → User data:**

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
    <title>PIDS Demo - JCC</title>
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
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 PIDS Demo - JCC</h1>
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
            Auto Scaling Group is working!
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

4. Click **Create launch template**

---

## Step 4: Create Target Group (5 minutes)

1. Go to **EC2** → **Target Groups**
2. Click **Create target group**
3. Fill in:
   - **Target type:** Instances
   - **Target group name:** `PIDS-demo-jcc-tg`
   - **Protocol:** HTTP
   - **Port:** 80
   - **VPC:** `vpc-049501e2e003cb81b`
   - **Health check path:** `/`
4. Click **Next**
5. Don't register any targets
6. Click **Create target group**

---

## Step 5: Create Application Load Balancer (10 minutes)

1. Go to **EC2** → **Load Balancers**
2. Click **Create load balancer**
3. Select **Application Load Balancer** → **Create**
4. Fill in:

**Basic configuration:**
- **Name:** `PIDS-demo-jcc-alb`
- **Scheme:** Internet-facing
- **IP address type:** IPv4

**Network mapping:**
- **VPC:** `vpc-049501e2e003cb81b`
- **Mappings:** Select 2 public subnets in different AZs

**Security groups:**
- Remove default
- Select `PIDS-demo-jcc-alb-sg`

**Listeners and routing:**
- **Protocol:** HTTP
- **Port:** 80
- **Default action:** `PIDS-demo-jcc-tg`

5. Click **Create load balancer**
6. Wait 2-3 minutes for state to become "Active"
7. **Copy the DNS name** - this is your ALB URL

---

## Step 6: Create Auto Scaling Group (10 minutes)

1. Go to **EC2** → **Auto Scaling Groups**
2. Click **Create Auto Scaling group**

**Step 1: Choose launch template**
- **Name:** `PIDS-demo-jcc-asg`
- **Launch template:** `PIDS-demo-jcc-template`
- Click **Next**

**Step 2: Choose instance launch options**
- **VPC:** `vpc-049501e2e003cb81b`
- **Subnets:** Select 2 public subnets
- Click **Next**

**Step 3: Configure advanced options**
- **Load balancing:** Attach to an existing load balancer
- **Target groups:** `PIDS-demo-jcc-tg`
- **Health checks:** Turn on ELB health checks
- **Grace period:** 300 seconds
- Click **Next**

**Step 4: Configure group size and scaling**
- **Desired capacity:** 2
- **Minimum capacity:** 2
- **Maximum capacity:** 5
- **Scaling policies:** Target tracking scaling policy
  - **Policy name:** `cpu-policy`
  - **Metric type:** Average CPU utilization
  - **Target value:** 50
- Click **Next**

**Step 5: Add notifications**
- Skip, click **Next**

**Step 6: Add tags**
- **Key:** Name
- **Value:** PIDS-demo-jcc
- Click **Next**

**Step 7: Review**
- Click **Create Auto Scaling group**

---

## Step 7: Verify and Get ALB URL (5 minutes)

### 7.1 Wait for Instances

1. Go to **Auto Scaling Groups** → `PIDS-demo-jcc-asg`
2. Click **Instance management** tab
3. Wait for 2 instances to show "InService" and "Healthy"
4. This takes 3-5 minutes

### 7.2 Check Target Group

1. Go to **Target Groups** → `PIDS-demo-jcc-tg`
2. Click **Targets** tab
3. Wait for both targets to show "healthy"

### 7.3 Get ALB URL

1. Go to **Load Balancers**
2. Select `PIDS-demo-jcc-alb`
3. Copy the **DNS name**
4. Open in browser: `http://[DNS-NAME]`

**Expected URL format:**
```
http://PIDS-demo-jcc-alb-XXXXXXXXX.us-east-1.elb.amazonaws.com
```

---

## Verification Checklist

- [ ] Security groups created
- [ ] Key pair created
- [ ] Launch template created with user data
- [ ] Target group created
- [ ] ALB created and active
- [ ] ASG created with 2/2/5 configuration
- [ ] 2 instances running and healthy
- [ ] ALB URL accessible in browser
- [ ] Website shows instance ID and AZ
- [ ] Refreshing page shows different instances

---

## Expected Result

When you access the ALB URL, you should see:
- Beautiful purple gradient page
- "PIDS Demo - JCC" title
- Instance ID (changes on refresh)
- Availability Zone (changes on refresh)
- "Auto Scaling Group is working!" message

---

## Troubleshooting

**ALB not accessible?**
- Check ALB state is "Active"
- Verify security group allows port 80 from 0.0.0.0/0
- Wait 5 minutes after creation

**Targets unhealthy?**
- Check instance security group allows port 80 from ALB
- Verify user data script ran correctly
- Check CloudWatch logs

**Instances not launching?**
- Verify subnets are public
- Check launch template configuration
- Review Auto Scaling activity history

---

## Cleanup Instructions

When done testing:

1. Delete Auto Scaling Group
2. Delete Load Balancer
3. Delete Target Group
4. Delete Launch Template
5. Delete Security Groups
6. Delete Key Pair

---

## Summary

**Resources Created:**
- 2 Security Groups
- 1 Key Pair
- 1 Launch Template
- 1 Target Group
- 1 Application Load Balancer
- 1 Auto Scaling Group
- 2 EC2 Instances (auto-created)

**Configuration:**
- VPC: vpc-049501e2e003cb81b
- Desired: 2 instances
- Min: 2 instances
- Max: 5 instances
- Scaling: CPU-based (50% target)

**Cost:** ~$0.02/hour for 2 t3.micro instances + ALB
