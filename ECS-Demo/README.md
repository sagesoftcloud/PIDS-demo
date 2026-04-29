# AWS ECS Basic Demo

A beginner-friendly guide to deploying your first Docker container on AWS ECS (Elastic Container Service).

## What You'll Build

- A simple web application running in a Docker container
- Deployed on AWS ECS using Fargate (serverless)
- Accessible via public IP address

## Prerequisites

- AWS Account credentials
- Basic understanding of containers (helpful but not required)
- 30-40 minutes of time

## What's Included

- `Dockerfile` - Container definition
- `index.html` - Sample web application
- `STEP_BY_STEP_GUIDE.md` - Complete deployment instructions

## Quick Overview

1. **Create ECR Repository** - Store your container image
2. **Build Docker Image** - Package your application
3. **Push to ECR** - Upload image to AWS
4. **Create ECS Cluster** - Set up container environment
5. **Define Task** - Specify container configuration
6. **Run Service** - Deploy and access your container

## Cost

- **Fargate:** ~$0.012/hour (0.25 vCPU, 0.5 GB memory)
- **2-hour demo:** ~$0.024 (2.4 cents)
- **ECR:** First 500 MB free

## Key Concepts

**ECS (Elastic Container Service):** AWS service for running containers

**Fargate:** Serverless compute engine for containers (no servers to manage)

**ECR (Elastic Container Registry):** Docker image storage

**Task Definition:** Blueprint for your container

**Service:** Ensures your containers keep running

## Getting Started

Follow the **STEP_BY_STEP_GUIDE.md** for detailed instructions.

## Architecture

```
Internet → Public IP → Fargate Task → Container → Web App
```

## What You'll Learn

- How to containerize applications
- How to use AWS ECR
- How to deploy containers with ECS
- How to use Fargate for serverless containers
- Container networking and security

## Cleanup

Always delete resources after testing to avoid charges:
1. Delete ECS Service
2. Delete ECS Cluster
3. Delete Task Definition
4. Delete ECR Repository
5. Delete Security Group

## Next Steps

- Add Application Load Balancer
- Implement auto-scaling
- Set up CI/CD pipeline
- Deploy multi-container applications
- Use ECS with EC2 instances

## Resources

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Fargate Documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)
- [Docker Documentation](https://docs.docker.com/)

---

**Ready to start?** Open `STEP_BY_STEP_GUIDE.md` and begin your ECS journey!
