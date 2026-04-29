# Step 1: Networking Setup

Create the VPC and networking components for the Auto Scaling Group.

## Overview

We'll create:
- VPC with CIDR block
- 2 Public subnets in different Availability Zones (required for ALB)
- Internet Gateway
- Route table

## Why Multiple Availability Zones?

Auto Scaling Groups distribute instances across AZs for:
- High availability
- Fault tolerance
- Better load distribution

## Step-by-Step Instructions

### 1. Create VPC

```bash
# Set variables
export AWS_REGION=us-east-1
export VPC_NAME=asg-demo-vpc
export VPC_CIDR=10.0.0.0/16

# Create VPC
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME}]" \
  --region $AWS_REGION \
  --query 'Vpc.VpcId' \
  --output text)

echo "VPC ID: $VPC_ID"

# Enable DNS hostnames
aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-hostnames \
  --region $AWS_REGION
```

### 2. Create Internet Gateway

```bash
# Create Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=asg-demo-igw}]" \
  --region $AWS_REGION \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

echo "Internet Gateway ID: $IGW_ID"

# Attach to VPC
aws ec2 attach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID \
  --region $AWS_REGION
```

### 3. Create Public Subnets

```bash
# Get availability zones
AZ1=$(aws ec2 describe-availability-zones \
  --region $AWS_REGION \
  --query 'AvailabilityZones[0].ZoneName' \
  --output text)

AZ2=$(aws ec2 describe-availability-zones \
  --region $AWS_REGION \
  --query 'AvailabilityZones[1].ZoneName' \
  --output text)

# Create Subnet 1
SUBNET1_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone $AZ1 \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=asg-demo-subnet-1}]" \
  --region $AWS_REGION \
  --query 'Subnet.SubnetId' \
  --output text)

echo "Subnet 1 ID: $SUBNET1_ID (AZ: $AZ1)"

# Create Subnet 2
SUBNET2_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 \
  --availability-zone $AZ2 \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=asg-demo-subnet-2}]" \
  --region $AWS_REGION \
  --query 'Subnet.SubnetId' \
  --output text)

echo "Subnet 2 ID: $SUBNET2_ID (AZ: $AZ2)"

# Enable auto-assign public IP
aws ec2 modify-subnet-attribute \
  --subnet-id $SUBNET1_ID \
  --map-public-ip-on-launch \
  --region $AWS_REGION

aws ec2 modify-subnet-attribute \
  --subnet-id $SUBNET2_ID \
  --map-public-ip-on-launch \
  --region $AWS_REGION
```

### 4. Create and Configure Route Table

```bash
# Create route table
RTB_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=asg-demo-rtb}]" \
  --region $AWS_REGION \
  --query 'RouteTable.RouteTableId' \
  --output text)

echo "Route Table ID: $RTB_ID"

# Add route to Internet Gateway
aws ec2 create-route \
  --route-table-id $RTB_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID \
  --region $AWS_REGION

# Associate subnets with route table
aws ec2 associate-route-table \
  --subnet-id $SUBNET1_ID \
  --route-table-id $RTB_ID \
  --region $AWS_REGION

aws ec2 associate-route-table \
  --subnet-id $SUBNET2_ID \
  --route-table-id $RTB_ID \
  --region $AWS_REGION
```

### 5. Save Configuration

```bash
# Save IDs for later use
cat > ~/asg-demo-config.sh << EOF
export AWS_REGION=$AWS_REGION
export VPC_ID=$VPC_ID
export IGW_ID=$IGW_ID
export SUBNET1_ID=$SUBNET1_ID
export SUBNET2_ID=$SUBNET2_ID
export RTB_ID=$RTB_ID
export AZ1=$AZ1
export AZ2=$AZ2
EOF

echo "Configuration saved to ~/asg-demo-config.sh"
echo "Run: source ~/asg-demo-config.sh to load variables"
```

## Verification

```bash
# Verify VPC
aws ec2 describe-vpcs \
  --vpc-ids $VPC_ID \
  --region $AWS_REGION

# Verify subnets
aws ec2 describe-subnets \
  --subnet-ids $SUBNET1_ID $SUBNET2_ID \
  --region $AWS_REGION

# Verify route table
aws ec2 describe-route-tables \
  --route-table-ids $RTB_ID \
  --region $AWS_REGION
```

## Troubleshooting

**Issue:** Subnet creation fails
- Check if CIDR blocks don't overlap
- Verify AZs are available in your region

**Issue:** No internet connectivity later
- Verify Internet Gateway is attached
- Check route table has 0.0.0.0/0 route to IGW
- Confirm subnets are associated with route table

## Next Steps

Proceed to [Step 2: Create Security Groups](./02-security-groups.md)
