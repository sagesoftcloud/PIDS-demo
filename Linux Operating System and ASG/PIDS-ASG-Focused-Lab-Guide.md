# PIDS AWS Immersion Day: Auto Scaling Groups (ASG)
**Hands-On Lab Guide**

---

## 📋 Session Overview
**Target Audience:** PIDS Technical Team  
**Duration:** 2 hours  
**Prerequisites:** Basic AWS Console knowledge  
**Objective:** Master ASG implementation and scaling policies

---

## 🏷️ **IMPORTANT: Naming Convention**

Since participants will share the same AWS account, **ALL resources must follow this naming convention:**

### **Format: `(YourName)-ResourceType-Service`**

**Examples:**
- EC2 Instance: `jim-webapp-ec2`
- Launch Template: `sarah-webserver-template`
- Auto Scaling Group: `mike-webapp-asg`
- Load Balancer: `anna-webapp-alb`
- Target Group: `john-webapp-tg`
- Security Group: `lisa-webapp-sg`

### **Resource Naming Rules:**
- **Use your first name or nickname** (lowercase)
- **Keep it short but descriptive**
- **Use hyphens (-) not underscores (_)**
- **No spaces in names**

**⚠️ CRITICAL: Always use your name prefix to avoid conflicts with other participants!**

---

# Discussion Session: Auto Scaling Groups (ASG)

## 🚀 When and How to Use Auto Scaling Groups (ASG)

### When to Use ASG:

#### ✅ Perfect Use Cases:
1. **Variable Traffic Patterns**
   - E-commerce sites with peak shopping hours
   - News websites during breaking news
   - Educational platforms during exam periods

2. **Cost Optimization**
   - Development/testing environments
   - Batch processing workloads
   - Seasonal applications

3. **High Availability Requirements**
   - Mission-critical applications
   - 24/7 services
   - Multi-region deployments

#### ❌ When NOT to Use ASG:
1. **Stateful Applications**
   - Databases with local storage
   - Applications with sticky sessions
   - Legacy monolithic applications

2. **Predictable, Constant Load**
   - Internal tools with fixed user base
   - Background processing with steady workload

### How ASG Works:

```
Traffic Increase → CloudWatch Metrics → Scaling Policy → Launch New Instances
Traffic Decrease → CloudWatch Metrics → Scaling Policy → Terminate Instances
```

### ASG Components:

#### 1. Launch Template/Configuration
- **AMI ID:** Base image for instances
- **Instance Type:** Hardware specifications
- **Security Groups:** Network access rules
- **User Data:** Bootstrap scripts
- **IAM Role:** Permissions for instances

#### 2. Auto Scaling Group
- **Min Size:** Minimum instances (e.g., 2)
- **Max Size:** Maximum instances (e.g., 10)
- **Desired Capacity:** Target instances (e.g., 3)
- **Availability Zones:** Distribution across AZs

#### 3. Scaling Policies
- **Target Tracking:** Maintain specific metric value
- **Step Scaling:** Scale based on metric thresholds
- **Simple Scaling:** Basic scale up/down actions

---

# Hands-on Implementation Labs

## Lab 1: Create Launch Template

### Step 1: Create Launch Template via AWS Console

1. **Navigate to EC2 Console → Launch Templates**
2. **Click "Create launch template"**
3. **Configure:**
   - **Name:** `(YourName)-WebServer-Template` (e.g., `jim-webserver-template`)
   - **AMI:** Use your current Production Image (will be restored as staging)
   - **Instance Type:** t3.micro
   - **Key Pair:** Select your key pair
   - **Security Groups:** Create new with HTTP (80) and SSH (22)
     - **Security Group Name:** `(YourName)-WebServer-SG` (e.g., `jim-webserver-sg`)
   - **IAM Role:** Create role with CloudWatchAgentServerPolicy

**Note:** Since you're using your production image as staging, ensure the image already contains your web application and necessary monitoring tools.

---

## Lab 2: Configure Auto Scaling Group

### Step 1: Create Auto Scaling Group

1. **Navigate to EC2 Console → Auto Scaling Groups**
2. **Click "Create Auto Scaling group"**
3. **Configure:**

#### Basic Configuration:
```
Name: (YourName)-WebServer-ASG (e.g., jim-webserver-asg)
Launch Template: (YourName)-WebServer-Template (latest version)
```

#### Network Configuration:
```
VPC: Default VPC
Subnets: Select 2-3 subnets in different AZs
```

#### Group Size:
```
Desired Capacity: 2
Minimum Capacity: 1  
Maximum Capacity: 6
```

#### Health Checks:
```
Health Check Type: ELB
Health Check Grace Period: 300 seconds
```

### Step 2: Configure Scaling Policies

#### Target Tracking Policy - CPU:
```
Policy Name: (YourName)-CPU-TargetTracking (e.g., jim-cpu-targettracking)
Metric Type: Average CPU Utilization
Target Value: 70%
```

#### Target Tracking Policy - Memory:
```
Policy Name: (YourName)-Memory-TargetTracking (e.g., jim-memory-targettracking)
Metric Type: Custom Metric
Namespace: PIDS/EC2
Metric Name: mem_used_percent
Target Value: 80%
```

#### Step Scaling Policy - Advanced:
```
Policy Name: (YourName)-StepScaling-CPU (e.g., jim-stepscaling-cpu)
Metric: CPU Utilization
Conditions:
- CPU >= 80%: Add 2 instances
- CPU >= 90%: Add 3 instances
- CPU <= 30%: Remove 1 instance
```

---

## Lab 3: Set up Application Load Balancer

### Step 1: Create Application Load Balancer

1. **Navigate to EC2 Console → Load Balancers**
2. **Click "Create Load Balancer" → Application Load Balancer**
3. **Configure:**

#### Basic Configuration:
```
Name: (YourName)-WebServer-ALB (e.g., jim-webserver-alb)
Scheme: Internet-facing
IP Address Type: IPv4
```

#### Network Mapping:
```
VPC: Default VPC
Subnets: Select same subnets as ASG (minimum 2 AZs)
- Example: ap-southeast-1a, ap-southeast-1b
```

#### Security Groups:
```
Create new security group:
Name: (YourName)-ALB-SG (e.g., jim-alb-sg)
- HTTP (80) from 0.0.0.0/0
- HTTPS (443) from 0.0.0.0/0 (optional)
```

### Step 2: Create Target Group

```
Name: (YourName)-WebServer-TG (e.g., jim-webserver-tg)
Protocol: HTTP
Port: 80
VPC: Default VPC

Health Check:
- Protocol: HTTP
- Path: /
- Healthy Threshold: 2
- Unhealthy Threshold: 5
- Timeout: 5 seconds
- Interval: 30 seconds
```

### Step 3: Configure Listeners and Rules

#### Default HTTP Listener (Port 80):
4. **In the "Listeners and routing" section:**
   ```
   Protocol: HTTP
   Port: 80
   Default action: Forward to target group
   Target group: (YourName)-WebServer-TG
   ```

#### Optional HTTPS Listener (Port 443):
5. **If you have SSL certificate, add HTTPS listener:**
   ```
   Protocol: HTTPS
   Port: 443
   Default action: Forward to target group
   Target group: (YourName)-WebServer-TG
   Security policy: ELBSecurityPolicy-TLS13-1-2-2021-06
   SSL Certificate: Select your certificate
   ```

#### HTTP to HTTPS Redirect (Optional):
6. **If using HTTPS, modify HTTP listener to redirect:**
   ```
   Protocol: HTTP
   Port: 80
   Default action: Redirect to HTTPS
   Redirect to: HTTPS://#{host}:443/#{path}?#{query}
   Status code: HTTP_301
   ```

### Step 4: Advanced Listener Rules (Optional)

## 📋 **Understanding ALB Rules and Routing Policies**

### **What are ALB Rules?**
ALB rules determine **where to send incoming requests** based on specific conditions. Think of them as **traffic directors** that examine incoming requests and route them to the appropriate backend services.

### **When to Use Different Routing Policies:**

#### **🛣️ Path-Based Routing**
**Use When:** You have different services running on different paths
**Example:** 
- `/api/*` → API servers
- `/images/*` → Image servers  
- `/admin/*` → Admin panel servers

**Real-World Scenario:** E-commerce site where product pages, API calls, and admin functions need different backend services.

#### **🌐 Host-Based Routing**
**Use When:** Multiple domains/subdomains point to the same load balancer
**Example:**
- `api.company.com` → API servers
- `admin.company.com` → Admin servers
- `blog.company.com` → Blog servers

**Real-World Scenario:** Microservices architecture where each subdomain represents a different service.

#### **🏥 Health Check Routing**
**Use When:** You need monitoring endpoints that don't hit your application
**Example:** `/health`, `/status`, `/ping` return simple "OK" responses
**Real-World Scenario:** Monitoring systems need to check if load balancer is working without affecting backend servers.

#### **🎯 Header-Based Routing**
**Use When:** You need to route based on request headers
**Example:** 
- `User-Agent: Mobile` → Mobile-optimized servers
- `X-API-Version: v2` → Version 2 API servers

**Real-World Scenario:** A/B testing or serving different content based on client type.

---

#### Path-Based Routing:
1. **Go to Load Balancers → (YourName)-WebServer-ALB**
2. **Click "Listeners and rules" tab**
3. **Select HTTP:80 listener → Click "Manage rules"**
4. **Add rule:**
   ```
   Rule name: (YourName)-API-Route
   Conditions:
   - Path: /api/*
   Actions:
   - Forward to: (YourName)-API-TG (if you have API target group)
   Priority: 100
   ```
   **💡 Use Case:** Separate your API traffic from web traffic for better monitoring and scaling.

#### Host-Based Routing:
5. **Add another rule:**
   ```
   Rule name: (YourName)-Subdomain-Route
   Conditions:
   - Host header: api.(yourdomain).com
   Actions:
   - Forward to: (YourName)-API-TG
   Priority: 200
   ```
   **💡 Use Case:** Multiple services under different subdomains using one load balancer.

#### Health Check Based Routing:
6. **Add health check rule:**
   ```
   Rule name: (YourName)-Health-Check
   Conditions:
   - Path: /health
   Actions:
   - Return fixed response
   Response code: 200
   Content-Type: text/plain
   Response body: "OK"
   Priority: 50
   ```
   **💡 Use Case:** Monitoring systems can check load balancer health without affecting backend servers.

### **🔢 Rule Priority Explained:**
- **Lower numbers = Higher priority** (Priority 1 runs before Priority 100)
- **Default rule** always has the lowest priority (runs last)
- **Best Practice:** Leave gaps between priorities (50, 100, 200) for future rules

### **⚡ Common Routing Patterns:**

#### **Microservices Pattern:**
```
Priority 10: /auth/* → Authentication Service
Priority 20: /api/users/* → User Service  
Priority 30: /api/orders/* → Order Service
Priority 40: /api/* → General API Service
Default: /* → Frontend Web Application
```

#### **Blue-Green Deployment Pattern:**
```
Priority 10: Header "X-Environment: green" → Green Target Group
Default: → Blue Target Group (current production)
```

#### **Maintenance Mode Pattern:**
```
Priority 5: Path /maintenance → Fixed Response "Under Maintenance"
Default: → Normal Target Group
```

### Step 5: Configure Target Group Stickiness (Optional)

1. **Go to Target Groups → (YourName)-WebServer-TG**
2. **Click "Actions" → "Edit attributes"**
3. **Configure stickiness:**
   ```
   Stickiness: Enabled
   Stickiness type: Load balancer generated cookie
   Stickiness duration: 1 day (86400 seconds)
   ```

### Step 6: Attach ASG to Load Balancer

1. **Go to Auto Scaling Groups → (YourName)-WebServer-ASG**
2. **Edit → Load Balancing**
3. **Select:** Application Load Balancer target groups
4. **Choose:** (YourName)-WebServer-TG

### Step 7: Verify Load Balancer Configuration

#### Check Listeners and Rules:
1. **Go to Load Balancers → (YourName)-WebServer-ALB**
2. **Click "Listeners and rules" tab**
3. **Verify you see:**
   ```
   HTTP:80 - Forward to (YourName)-WebServer-TG
   HTTPS:443 - Forward to (YourName)-WebServer-TG (if configured)
   Rules: X rules (including any custom rules you added)
   ```

#### Check Load Balancer Details:
4. **In the "Details" tab, verify:**
   ```
   Load balancer type: Application
   Scheme: Internet-facing
   Status: Active
   VPC: Your selected VPC
   Availability Zones: 2+ zones selected
   DNS name: (YourName)-WebServer-ALB-xxxxxxxxx.region.elb.amazonaws.com
   ```

#### Test Load Balancer:
5. **Copy the DNS name and test in browser:**
   ```
   http://(YourName)-WebServer-ALB-xxxxxxxxx.region.elb.amazonaws.com
   ```

### Step 8: Monitor Load Balancer Health

#### Check Target Health:
1. **Go to Target Groups → (YourName)-WebServer-TG**
2. **Click "Targets" tab**
3. **Verify targets show "healthy" status**

#### View Load Balancer Metrics:
4. **Go to Load Balancers → (YourName)-WebServer-ALB**
5. **Click "Monitoring" tab**
6. **Key metrics to watch:**
   ```
   - Request Count
   - Target Response Time
   - HTTP 2XX/4XX/5XX Count
   - Healthy Host Count
   - UnHealthy Host Count
   ```

### Step 9: Advanced Configuration Options

#### Connection Draining:
```
Deregistration delay: 300 seconds
(Time to complete in-flight requests before removing target)
```

#### Cross-Zone Load Balancing:
```
Cross-zone load balancing: Enabled
(Distribute traffic evenly across all AZs)
```

#### Access Logs (Optional):
```
Access logs: Enabled
S3 bucket: (YourName)-alb-access-logs
Prefix: access-logs/
```

---

## 🎯 **Lab 3 Validation Checklist:**

### ✅ Load Balancer Setup:
- [ ] ALB created and shows "Active" status
- [ ] DNS name accessible from internet
- [ ] Security groups allow HTTP/HTTPS traffic
- [ ] Deployed across multiple AZs

### ✅ Listeners Configuration:
- [ ] HTTP:80 listener configured
- [ ] HTTPS:443 listener configured (if using SSL)
- [ ] Default actions point to correct target group
- [ ] Custom rules working (if configured)

### ✅ Target Group Health:
- [ ] Target group shows healthy instances
- [ ] Health checks passing
- [ ] ASG instances automatically registered
- [ ] Traffic distributed across instances

### ✅ Routing Verification:
- [ ] Web requests reach backend instances
- [ ] Load balancing working (refresh shows different instances)
- [ ] Custom routing rules functioning (if configured)
- [ ] SSL termination working (if HTTPS configured)

---

**🎓 Lab 3 Complete! Your Application Load Balancer is now properly configured with listeners, rules, and health checks.**

---

## Lab 4: Understanding All Scaling Policy Types & Implementation

### 🎯 Lab Objective:
Learn the differences between all 4 scaling policy types available in AWS, how they trigger, and implement each type step-by-step.

---

## 📊 All 4 Scaling Policy Types Explained

### **1. Target Tracking Scaling (Dynamic)**
**What it does:** Maintains a specific metric value (like thermostat)
**Best for:** Steady-state applications with predictable patterns
**Console Location:** Dynamic scaling policies

**How it works:**
- You set a target value (e.g., 70% CPU)
- ASG automatically adds/removes instances to maintain that target
- AWS handles all the math and timing
- Scale-in can be enabled/disabled

**Example:** Keep CPU at exactly 70%
- Current CPU: 85% → Add instances until CPU drops to 70%
- Current CPU: 50% → Remove instances until CPU rises to 70%

### **2. Step Scaling (Dynamic)**
**What it does:** Different actions based on how far you are from the threshold
**Best for:** Applications with varying load intensities
**Console Location:** Dynamic scaling policies

**How it works:**
- Define multiple thresholds with different actions
- Bigger problems = bigger responses
- More granular control than simple scaling

**Example:** CPU-based step scaling
- CPU 70-80%: Add 1 instance
- CPU 80-90%: Add 2 instances  
- CPU >90%: Add 3 instances

### **3. Simple Scaling (Dynamic)**
**What it does:** Single action when threshold is crossed
**Best for:** Basic scenarios or legacy applications
**Console Location:** Dynamic scaling policies

**How it works:**
- One threshold = one action
- Must wait for cooldown period before next action
- Less sophisticated but easier to understand

**Example:** If CPU > 80%, add 1 instance, wait 5 minutes

### **4. Predictive Scaling**
**What it does:** Uses machine learning to predict and pre-scale
**Best for:** Applications with recurring traffic patterns
**Console Location:** Predictive scaling policies

**How it works:**
- Analyzes historical data (minimum 2 days)
- Forecasts hourly load patterns
- Pre-scales before predicted load increases
- Can work in "Forecast only" or "Forecast and scale" mode

**Example:** Every Monday 9 AM traffic increases 3x
- Predictive scaling learns this pattern
- Adds instances at 8:55 AM on Mondays automatically

### **5. Scheduled Actions**
**What it does:** Scale at specific times/dates
**Best for:** Known traffic patterns (business hours, events)
**Console Location:** Scheduled actions

**How it works:**
- Set specific times to change capacity
- Can be one-time or recurring
- Overrides other scaling policies during scheduled time

**Example:** Scale up every weekday at 8 AM, scale down at 6 PM

---

## 🛠️ Step-by-Step Implementation

### **Implementation 1: Target Tracking Scaling**

#### Step 1: Create Target Tracking Policy via Console
1. **Go to Auto Scaling Groups → (YourName)-WebServer-ASG**
2. **Click "Automatic scaling" tab**
3. **Under "Dynamic scaling policies" → Click "Create dynamic scaling policy"**
4. **Configure:**
   ```
   Policy type: Target tracking scaling
   Policy name: (YourName)-CPU-TargetTracking
   Metric type: Average CPU utilization
   Target value: 70
   Instance warmup: 300 seconds
   Scale in: Enabled
   ```

#### Step 2: Observe Target Tracking in Console
**What you'll see in the console:**
- Policy shows: "Execute policy when: As required to maintain Average CPU utilization at 70"
- Action: "Add or remove capacity units as required"
- Warmup: "Instances need 300 seconds to warm up before including in metric"
- Scale in: "Enabled"

---

### **Implementation 2: Step Scaling Policy**

#### Step 1: Create CloudWatch Alarms via Console
1. **Go to CloudWatch Console → Alarms → All alarms**
2. **Click "Create alarm"**

**Create High CPU Alarm (80%):**
3. **Select metric:**
   - Click "Select metric"
   - Choose "EC2" → "By Auto Scaling Group"
   - Find your ASG: `(YourName)-WebServer-ASG`
   - Select "CPUUtilization" → Click "Select metric"

4. **Configure alarm:**
   ```
   Statistic: Average
   Period: 5 minutes
   Threshold type: Static
   Whenever CPUUtilization is: Greater than 80
   ```

5. **Configure actions:**
   ```
   Alarm state trigger: In alarm
   Send a notification to: (Skip - not needed for ASG)
   ```

6. **Name and description:**
   ```
   Alarm name: (YourName)-CPU-High-80
   Alarm description: CPU above 80% for ASG scaling
   ```

**Create Very High CPU Alarm (90%):**
7. **Repeat steps 2-6 with these changes:**
   ```
   Threshold: Greater than 90
   Alarm name: (YourName)-CPU-High-90
   Alarm description: CPU above 90% for aggressive scaling
   ```

**Create Low CPU Alarm (30%):**
8. **Repeat steps 2-6 with these changes:**
   ```
   Threshold: Less than 30
   Alarm name: (YourName)-CPU-Low-30
   Alarm description: CPU below 30% for scale-in
   ```

#### Step 2: Create Step Scaling Policy via Console
1. **Go to Auto Scaling Groups → (YourName)-WebServer-ASG**
2. **Click "Automatic scaling" tab**
3. **Under "Dynamic scaling policies" → Click "Create dynamic scaling policy"**

**Create Scale-Out Policy:**
4. **Configure:**
   ```
   Policy type: Step scaling
   Policy name: (YourName)-StepScaling-Out
   CloudWatch alarm: (YourName)-CPU-High-80
   
   Take the action: Add
   Step adjustments:
   - 80 to 90: Add 1 capacity units
   - 90 to +infinity: Add 2 capacity units
   
   Instance warmup: 300 seconds
   ```

**Create Scale-In Policy:**
5. **Click "Create dynamic scaling policy" again**
6. **Configure:**
   ```
   Policy type: Step scaling
   Policy name: (YourName)-StepScaling-In
   CloudWatch alarm: (YourName)-CPU-Low-30
   
   Take the action: Remove
   Step adjustments:
   - -infinity to 30: Remove 1 capacity units
   
   Instance warmup: 300 seconds
   ```

---

## Lab 5: Test Scaling Behavior

### Load Testing Setup

#### Option 1: Using Apache Bench (ab)
```bash
# Install on your local machine or another EC2 instance
sudo yum install -y httpd-tools

# Generate load
ab -n 10000 -c 100 http://YOUR-ALB-DNS-NAME/

# Monitor in real-time
watch -n 5 'ab -n 100 -c 10 http://YOUR-ALB-DNS-NAME/ | grep "Requests per second"'
```

#### Option 2: Using Artillery (Node.js)
```bash
# Install Node.js and Artillery
curl -sL https://rpm.nodesource.com/setup_16.x | sudo bash -
sudo yum install -y nodejs
npm install -g artillery

# Create load test configuration
cat > load-test.yml << 'EOF'
config:
  target: 'http://YOUR-ALB-DNS-NAME'
  phases:
    - duration: 300
      arrivalRate: 10
    - duration: 300  
      arrivalRate: 50
    - duration: 300
      arrivalRate: 100

scenarios:
  - name: "Load test PIDS web server"
    requests:
      - get:
          url: "/"
      - get:
          url: "/cpu-load"
EOF

# Run load test
artillery run load-test.yml
```

### Monitoring During Load Test

#### CloudWatch Metrics to Watch:
1. **EC2 Metrics:**
   - CPU Utilization
   - Memory Utilization (custom)
   - Network In/Out

2. **ASG Metrics:**
   - Group Desired Capacity
   - Group In Service Instances
   - Group Total Instances

3. **ALB Metrics:**
   - Request Count
   - Target Response Time
   - Healthy Host Count

#### Real-time Monitoring Commands:
```bash
# Watch ASG activity
aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names (YourName)-WebServer-ASG \
    --query 'AutoScalingGroups[0].{Desired:DesiredCapacity,Min:MinSize,Max:MaxSize,Current:Instances[?LifecycleState==`InService`] | length(@)}'

# Monitor scaling activities
aws autoscaling describe-scaling-activities \
    --auto-scaling-group-name (YourName)-WebServer-ASG \
    --max-items 5
```

---

## 🎯 Lab Validation Checklist

### ✅ Successful Implementation Criteria:

#### ASG Configuration:
- [ ] Launch template created with web server
- [ ] ASG launches minimum instances
- [ ] Instances distributed across multiple AZs
- [ ] Health checks configured properly

#### Load Balancer:
- [ ] ALB accessible from internet
- [ ] Target group shows healthy instances
- [ ] Traffic distributed across instances

#### Scaling Behavior:
- [ ] Scale-out triggered at 70% CPU
- [ ] New instances launch within 5 minutes
- [ ] Scale-in occurs when load decreases
- [ ] Cooldown periods respected

#### Monitoring:
- [ ] CloudWatch metrics visible
- [ ] Custom metrics reporting
- [ ] Scaling activities logged
- [ ] Alarms configured

---

## 📚 Best Practices Summary

### 1. Launch Template Best Practices:
- Use latest AMI with security patches
- Include comprehensive user data scripts
- Configure IAM roles with minimal permissions
- Use placement groups for high-performance workloads

### 2. ASG Best Practices:
- Distribute across multiple AZs
- Set appropriate health check grace periods
- Use target tracking for predictable workloads
- Implement step scaling for rapid changes

### 3. Monitoring Best Practices:
- Enable detailed monitoring
- Set up custom metrics for application-specific data
- Configure CloudWatch alarms for proactive alerts
- Use AWS X-Ray for distributed tracing

### 4. Cost Optimization:
- Use Spot Instances for fault-tolerant workloads
- Implement scheduled scaling for predictable patterns
- Right-size instances based on actual usage
- Use Reserved Instances for baseline capacity

---

## 🎓 Lab Completion

### Deliverables:
1. **Working ASG** with 2-6 instances
2. **Load Balancer** distributing traffic
3. **Scaling policies** responding to load
4. **Monitoring dashboard** showing metrics
5. **Load test results** demonstrating scaling

---

**🏆 Congratulations! You've successfully implemented a production-ready Auto Scaling solution for PIDS infrastructure.**
