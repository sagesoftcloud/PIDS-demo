# AWS ECS Basic Demo - Step-by-Step Guide

Welcome! This guide will help you deploy your first container on AWS ECS (Elastic Container Service).

**Time Required:** 30-40 minutes  
**Cost:** ~$0.10 for 2-hour test (Fargate pricing)  
**Difficulty:** Beginner-friendly

---

## What is AWS ECS?

AWS ECS (Elastic Container Service) lets you run Docker containers without managing servers. Think of it like running apps in isolated boxes that can be easily moved and scaled.

**What is a Container?** A lightweight package that includes your application and everything it needs to run.

---

## Before You Start

### What You Need:
- AWS Account credentials (provided by instructor)
- Account ID: 192957544618
- Web browser
- 30-40 minutes of time

### What You'll Build:
- A Docker container running a web application
- Deployed on AWS ECS using Fargate (serverless)
- Accessible via the internet

---

## Step 1: Sign In to AWS Console (3 minutes)

1. Go to https://console.aws.amazon.com
2. Sign in with your credentials
3. Select **US East (N. Virginia)** region (top-right corner)

---

## Step 2: Create ECR Repository (5 minutes)

ECR (Elastic Container Registry) is where we store our container images.

### 2.1 Open ECR Service

1. Click the **search bar** at the top
2. Type **ECR**
3. Click **Elastic Container Registry**

### 2.2 Create Repository

1. Click **Get Started** or **Create repository**
2. Fill in:
   - **Visibility settings:** Private
   - **Repository name:** `ecs-demo-yourname` (replace yourname)
3. Click **Create repository**

**Write this down:** Repository URI (looks like: 123456789012.dkr.ecr.us-east-1.amazonaws.com/ecs-demo-yourname)

---

## Step 3: Build and Push Docker Image (10 minutes)

### 3.1 Open CloudShell

1. Click the **CloudShell icon** (terminal icon) at the top-right of AWS Console
2. Wait for CloudShell to initialize (30 seconds)

### 3.2 Create Project Files

In CloudShell, run these commands:

```bash
# Create project directory
mkdir ecs-demo
cd ecs-demo

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

# Create index.html
cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>ECS Demo</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0;
        }
        .container {
            background: white;
            padding: 50px;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            text-align: center;
        }
        h1 { color: #667eea; font-size: 3em; }
        .status { 
            background: #28a745; 
            color: white; 
            padding: 15px 30px; 
            border-radius: 50px; 
            margin: 20px 0;
            display: inline-block;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🐳 ECS Demo</h1>
        <div class="status">✅ Container Running Successfully</div>
        <p>This container is running on AWS ECS with Fargate</p>
    </div>
</body>
</html>
EOF
```

### 3.3 Build Docker Image

```bash
# Build the image
docker build -t ecs-demo .
```

**You should see:** "Successfully built" message

### 3.4 Push to ECR

Now we'll use the commands from ECR console to push your image.

**Navigate to ECR:**
1. In the AWS Console search bar, type **ECR**
2. Click **Elastic Container Registry**
3. Click on your repository name: `ecs-demo-yourname`
4. Click **View push commands** button (top-right)
5. A popup will show 4 commands - follow them in order:

**Command 1: Authenticate Docker to ECR**
- Copy the first command from the popup
- Paste it in CloudShell and press Enter
- You should see: "Login Succeeded"

**Command 2: Build your Docker image**
- Skip this (we already built it in step 3.3)

**Command 3: Tag your image**
- Copy the third command from the popup
- Paste in CloudShell and press Enter

**Command 4: Push to ECR**
- Copy the fourth command from the popup
- Paste in CloudShell and press Enter
- You should see upload progress bars

**Wait 1-2 minutes** for the push to complete.

**Verify:** Refresh your repository page, and you should see your image with tag `latest`.

---

## Step 4: Create ECS Cluster (5 minutes)

### 4.1 Open ECS Service

1. In the search bar, type **ECS**
2. Click **Elastic Container Service**

### 4.2 Create Cluster

1. Click **Clusters** in the left menu
2. Click **Create cluster**
3. Fill in:
   - **Cluster name:** `ecs-demo-cluster-yourname`
   - **Infrastructure:** AWS Fargate (serverless)
4. Click **Create**

**Wait 30 seconds** for cluster creation.

---

## Step 5: Create Task Definition (7 minutes)

A Task Definition is like a blueprint for your container.

### 5.1 Create Task Definition

1. Click **Task definitions** in the left menu
2. Click **Create new task definition**
3. Click **Create new task definition** again

### 5.2 Configure Task

**Task definition family:**
- **Task definition family name:** `ecs-demo-task-yourname`

**Infrastructure requirements:**
- **Launch type:** AWS Fargate
- **Operating system/Architecture:** Linux/X86_64
- **CPU:** 0.25 vCPU
- **Memory:** 0.5 GB

**Container - 1:**
- **Name:** `ecs-demo-container`
- **Image URI:** Paste your ECR repository URI with `:latest` tag
  - Example: `123456789012.dkr.ecr.us-east-1.amazonaws.com/ecs-demo-yourname:latest`
- **Port mappings:**
  - **Container port:** 80
  - **Protocol:** TCP
  - **Port name:** `http`
  - **App protocol:** HTTP

### 5.3 Create

1. Scroll down and click **Create**
2. Wait for "Successfully created" message

---

## Step 6: Create and Run Service (7 minutes)

### 6.1 Deploy Service

1. Go back to **Clusters**
2. Click on your cluster: `ecs-demo-cluster-yourname`
3. Click **Create** under Services tab
4. Fill in:

**Environment:**
- **Compute options:** Launch type
- **Launch type:** FARGATE

**Deployment configuration:**
- **Application type:** Service
- **Family:** Select `ecs-demo-task-yourname`
- **Service name:** `ecs-demo-service-yourname`
- **Desired tasks:** 1

**Networking:**
- **VPC:** Select `myvpc-pids-demo-vpc`
- **Subnets:** Select 2 public subnets
- **Security group:** Create new security group
  - **Security group name:** `ecs-demo-sg-yourname`
  - **Inbound rules:** 
    - Type: HTTP
    - Port: 80
    - Source: Anywhere (0.0.0.0/0)
- **Public IP:** Turned on (ENABLED)

### 6.2 Create Service

1. Click **Create**
2. Wait 2-3 minutes for service to start

---

## Step 7: Access Your Container (3 minutes)

### 7.1 Get Public IP

1. In your cluster, click the **Tasks** tab
2. Click on your running task
3. Find the **Public IP** address
4. Copy it

### 7.2 Access in Browser

1. Open a new browser tab
2. Type: `http://YOUR_PUBLIC_IP`
3. Press Enter

**You should see:** Your beautiful ECS demo page! 🎉

---

## Understanding What You Built

### Architecture:

```
Internet
   ↓
Public IP (Fargate Task)
   ↓
Container (Nginx)
   ↓
Your Web Application
```

### Components:

1. **ECR Repository** - Stores your container image
2. **ECS Cluster** - Logical grouping of tasks
3. **Task Definition** - Blueprint for your container
4. **Service** - Ensures your task keeps running
5. **Fargate** - Serverless compute for containers

---

## Key Concepts

**Container:** Packaged application with dependencies

**Image:** Template for creating containers

**Task:** Running instance of a task definition

**Service:** Maintains desired number of tasks

**Fargate:** Serverless - no servers to manage!

---

## Cleanup (5 minutes)

**Important:** Delete everything to avoid charges!

### Step 1: Delete Service

1. Go to your cluster
2. Click on your service
3. Click **Delete service**
4. Type `delete` and confirm
5. Wait 2 minutes

### Step 2: Delete Cluster

1. Go to **Clusters**
2. Select your cluster
3. Click **Delete cluster**
4. Type `delete` and confirm

### Step 3: Delete Task Definition

1. Go to **Task definitions**
2. Select your task definition
3. Click **Actions** → **Deregister**
4. Confirm

### Step 4: Delete ECR Repository

1. Go to **ECR**
2. Select your repository
3. Click **Delete**
4. Type `delete` and confirm

### Step 5: Delete Security Group

1. Go to **EC2** → **Security Groups**
2. Find `ecs-demo-sg-yourname`
3. Click **Actions** → **Delete security groups**
4. Confirm

---

## Cost Breakdown

### Fargate Pricing:
- **vCPU:** $0.04048 per vCPU per hour
- **Memory:** $0.004445 per GB per hour

### Our Configuration (0.25 vCPU, 0.5 GB):
- **Per hour:** ~$0.012
- **2 hours:** ~$0.024 (2.4 cents)

**ECR Storage:** First 500 MB free per month

---

## Troubleshooting

### Task Won't Start?
- Check security group allows port 80
- Verify public IP is enabled
- Check CloudWatch logs for errors

### Can't Access Website?
- Wait 2-3 minutes after task starts
- Use HTTP (not HTTPS)
- Check security group inbound rules

### Image Push Failed?
- Verify ECR login command
- Check repository URI is correct
- Ensure you're in the right region

---

## What You Learned

✅ How to containerize an application
✅ How to push images to ECR
✅ How to create ECS clusters
✅ How to define and run tasks
✅ How to deploy containers with Fargate
✅ Serverless container concepts

---

## Next Steps

1. **Add Load Balancer** - Distribute traffic across multiple tasks
2. **Auto Scaling** - Scale based on CPU/memory
3. **Multiple Containers** - Run multiple services
4. **CI/CD Pipeline** - Automate deployments
5. **Use Docker Compose** - Define multi-container apps

---

## Resources

- [ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Fargate Pricing](https://aws.amazon.com/fargate/pricing/)
- [Docker Basics](https://docs.docker.com/get-started/)

---

**Congratulations!** You've deployed your first container on AWS ECS! 🎉
