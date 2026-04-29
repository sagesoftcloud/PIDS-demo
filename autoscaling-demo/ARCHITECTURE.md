# Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                           Internet Users                             │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             │ HTTP/HTTPS
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Application Load Balancer                         │
│                    (asg-demo-alb)                                    │
│                                                                       │
│  Security Group: Allow 80/443 from 0.0.0.0/0                        │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             │ Health Checks
                             │ /health.html
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        Target Group                                  │
│                      (asg-demo-tg)                                   │
│                                                                       │
│  Health Check: HTTP /health.html every 30s                          │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             │ Distributes traffic
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Auto Scaling Group                                │
│                    (asg-demo-group)                                  │
│                                                                       │
│  Min: 1  │  Desired: 2  │  Max: 5                                   │
│                                                                       │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐ │
│  │   EC2 Instance   │  │   EC2 Instance   │  │   EC2 Instance   │ │
│  │   (t3.micro)     │  │   (t3.micro)     │  │   (t3.micro)     │ │
│  │                  │  │                  │  │                  │ │
│  │  AZ: us-east-1a  │  │  AZ: us-east-1b  │  │  AZ: us-east-1a  │ │
│  │                  │  │                  │  │                  │ │
│  │  - Apache        │  │  - Apache        │  │  - Apache        │ │
│  │  - Stress tool   │  │  - Stress tool   │  │  - Stress tool   │ │
│  │  - Metrics       │  │  - Metrics       │  │  - Metrics       │ │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘ │
│                                                                       │
│  Security Group: Allow 80 from ALB, 22 from your IP                 │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             │ Publishes metrics
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        CloudWatch                                    │
│                                                                       │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │
│  │  CPU Metrics    │  │  Alarms         │  │  Dashboard      │    │
│  │  - Utilization  │  │  - High CPU     │  │  - Capacity     │    │
│  │  - Network      │  │  - Low CPU      │  │  - Health       │    │
│  │  - Disk         │  │  - Unhealthy    │  │  - Requests     │    │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘    │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             │ Triggers
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      Scaling Policies                                │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Target Tracking: Maintain 50% CPU                           │  │
│  │  - Scale out when CPU > 50%                                  │  │
│  │  - Scale in when CPU < 50%                                   │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Step Scaling: Scale based on severity                       │  │
│  │  - CPU 70-80%: Add 10% capacity                              │  │
│  │  - CPU 80-90%: Add 20% capacity                              │  │
│  │  - CPU > 90%: Add 30% capacity                               │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Scheduled Scaling: Time-based patterns                      │  │
│  │  - 9 AM: Scale to 4 instances                                │  │
│  │  - 6 PM: Scale to 2 instances                                │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## Network Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         VPC (10.0.0.0/16)                            │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                    Internet Gateway                             │ │
│  └──────────────────────────┬─────────────────────────────────────┘ │
│                             │                                         │
│  ┌──────────────────────────┴─────────────────────────────────────┐ │
│  │                      Route Table                                │ │
│  │  0.0.0.0/0 -> Internet Gateway                                 │ │
│  └──────────────────────────┬─────────────────────────────────────┘ │
│                             │                                         │
│         ┌───────────────────┴───────────────────┐                   │
│         │                                       │                   │
│  ┌──────▼──────────────┐              ┌────────▼────────────────┐  │
│  │  Public Subnet 1    │              │  Public Subnet 2        │  │
│  │  10.0.1.0/24        │              │  10.0.2.0/24            │  │
│  │  AZ: us-east-1a     │              │  AZ: us-east-1b         │  │
│  │                     │              │                         │  │
│  │  - ALB (part 1)     │              │  - ALB (part 2)         │  │
│  │  - EC2 Instances    │              │  - EC2 Instances        │  │
│  └─────────────────────┘              └─────────────────────────┘  │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Application Load Balancer (ALB)
- **Type:** Application Load Balancer (Layer 7)
- **Scheme:** Internet-facing
- **Subnets:** 2 public subnets in different AZs
- **Security:** Allows HTTP (80) and HTTPS (443) from internet
- **Health Checks:** HTTP GET /health.html every 30 seconds

### 2. Target Group
- **Protocol:** HTTP
- **Port:** 80
- **Health Check Path:** /health.html
- **Health Check Interval:** 30 seconds
- **Healthy Threshold:** 2 consecutive successes
- **Unhealthy Threshold:** 3 consecutive failures

### 3. Auto Scaling Group
- **Launch Template:** asg-demo-template
- **Instance Type:** t3.micro (2 vCPU, 1 GiB RAM)
- **AMI:** Amazon Linux 2
- **Capacity:**
  - Minimum: 1 instance
  - Desired: 2 instances
  - Maximum: 5 instances
- **Health Check Type:** ELB (Load Balancer)
- **Health Check Grace Period:** 300 seconds
- **Availability Zones:** 2 (us-east-1a, us-east-1b)

### 4. EC2 Instances
- **Operating System:** Amazon Linux 2
- **Web Server:** Apache (httpd)
- **Stress Tool:** stress (for CPU testing)
- **Monitoring:** CloudWatch Agent
- **User Data:** Automated setup script
- **IAM Role:** CloudWatch permissions

### 5. Launch Template
- **Version:** Latest
- **Instance Type:** t3.micro
- **Security Group:** Instance security group
- **Key Pair:** asg-demo-key
- **IAM Instance Profile:** asg-demo-ec2-profile
- **Monitoring:** Detailed (1-minute intervals)
- **Metadata:** IMDSv2 required

### 6. Security Groups

**ALB Security Group:**
- Inbound: TCP 80 from 0.0.0.0/0
- Inbound: TCP 443 from 0.0.0.0/0
- Outbound: All traffic

**Instance Security Group:**
- Inbound: TCP 80 from ALB Security Group
- Inbound: TCP 22 from your IP
- Outbound: All traffic

### 7. Scaling Policies

**Target Tracking (Default):**
- Target: 50% CPU utilization
- Scale out cooldown: 60 seconds
- Scale in cooldown: 300 seconds

**Step Scaling (Optional):**
- CPU 70-80%: Add 10% capacity
- CPU 80-90%: Add 20% capacity
- CPU > 90%: Add 30% capacity
- CPU < 30%: Remove 1 instance

**Scheduled Scaling (Optional):**
- 9 AM weekdays: Scale to 4 instances
- 6 PM weekdays: Scale to 2 instances
- Weekends: Scale to 1 instance

### 8. CloudWatch Monitoring

**Metrics Collected:**
- CPU Utilization
- Network In/Out
- Disk Read/Write
- Request Count
- Target Response Time
- Healthy/Unhealthy Host Count

**Alarms:**
- High CPU (> 70%)
- Low CPU (< 30%)
- No Healthy Targets
- High Error Rate (5xx)

## Data Flow

### Normal Request Flow

1. User sends HTTP request to ALB DNS name
2. ALB receives request on port 80
3. ALB checks target health
4. ALB selects healthy target using round-robin
5. ALB forwards request to EC2 instance
6. Instance processes request and returns response
7. ALB returns response to user

### Scaling Flow

**Scale Out:**
1. Instance CPU exceeds 50%
2. CloudWatch publishes metric
3. Target tracking policy detects deviation
4. ASG launches new instance
5. Instance starts, runs user data script
6. Instance registers with target group
7. Health checks pass (2 consecutive)
8. ALB starts sending traffic to new instance

**Scale In:**
1. Average CPU drops below 50%
2. CloudWatch publishes metric
3. Target tracking policy detects deviation
4. ASG waits for scale-in cooldown (300s)
5. ASG selects instance to terminate (oldest)
6. ASG deregisters instance from target group
7. ALB drains connections (30s)
8. ASG terminates instance

### Health Check Flow

1. ALB sends HTTP GET /health.html every 30s
2. Instance responds with "OK"
3. If 2 consecutive successes: Mark healthy
4. If 3 consecutive failures: Mark unhealthy
5. Unhealthy instances removed from rotation
6. ASG terminates unhealthy instances
7. ASG launches replacement instances

## Scaling Scenarios

### Scenario 1: CPU Spike
```
Time: 0s    - 2 instances, 20% CPU
Time: 60s   - CPU stress started, 80% CPU
Time: 120s  - Alarm triggers, scale out initiated
Time: 180s  - New instance launching
Time: 300s  - New instance healthy, 3 instances total
Time: 360s  - Load distributed, 50% CPU per instance
```

### Scenario 2: Traffic Spike
```
Time: 0s    - 2 instances, 100 req/s
Time: 30s   - Traffic increases to 1000 req/s
Time: 60s   - CPU increases to 70%
Time: 90s   - Alarm triggers, scale out
Time: 150s  - New instance healthy
Time: 180s  - 3 instances handling 333 req/s each
```

### Scenario 3: Instance Failure
```
Time: 0s    - 2 healthy instances
Time: 30s   - Instance 1 fails health check
Time: 60s   - Instance 1 fails 2nd health check
Time: 90s   - Instance 1 fails 3rd health check, marked unhealthy
Time: 120s  - ASG launches replacement instance
Time: 420s  - New instance healthy (300s grace period)
Time: 450s  - ASG terminates failed instance
```

## Cost Breakdown

### Hourly Costs
- EC2 t3.micro: $0.0104/hour × 2 instances = $0.0208/hour
- Application Load Balancer: $0.0225/hour
- Data transfer: ~$0.001/hour (minimal for testing)
- CloudWatch: Included in free tier for basic metrics
- **Total: ~$0.044/hour**

### Demo Costs (2 hours)
- EC2: $0.0416
- ALB: $0.045
- Data transfer: $0.002
- **Total: ~$0.09**

### Monthly Costs (if left running)
- EC2: $15.00
- ALB: $16.20
- Data transfer: $1.00
- **Total: ~$32.20/month**

**Important:** Always run cleanup script after demo!

## Best Practices Implemented

1. **High Availability:** Multi-AZ deployment
2. **Security:** Least privilege security groups
3. **Monitoring:** Detailed CloudWatch metrics
4. **Auto-healing:** ELB health checks
5. **Cost Optimization:** Burstable instances (t3.micro)
6. **Scalability:** Auto Scaling based on demand
7. **Observability:** Custom metrics and dashboard
8. **Documentation:** Comprehensive guides

## Limitations

1. **Single Region:** Demo uses one region only
2. **No SSL:** HTTP only (HTTPS requires certificate)
3. **Basic Application:** Simple web server
4. **No Database:** Stateless application
5. **No CDN:** Direct ALB access
6. **Development Grade:** Not production-ready

## Production Enhancements

To make this production-ready:

1. **SSL/TLS:** Add ACM certificate and HTTPS listener
2. **Multi-Region:** Deploy to multiple regions
3. **Database:** Add RDS with read replicas
4. **Caching:** Add ElastiCache or CloudFront
5. **Monitoring:** Add X-Ray, detailed logging
6. **Security:** WAF, Shield, GuardDuty
7. **Backup:** Automated snapshots
8. **CI/CD:** Automated deployments
9. **Secrets:** Use Secrets Manager
10. **Compliance:** Enable Config, CloudTrail
