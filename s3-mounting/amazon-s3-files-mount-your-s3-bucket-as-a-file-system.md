# Amazon S3 Files: Mount Your S3 Bucket as a File System — Hands-On Practical Guide

> **Last Updated:** April 29, 2026
>
> **Service GA Date:** April 7, 2026
>
> **Tested On:** Amazon Linux 2023 | AWS CLI 2.34+ | amazon-efs-utils 3.0.0

---

## Table of Contents

1. [What is Amazon S3 Files?](#what-is-amazon-s3-files)
2. [How Does S3 Files Work?](#how-does-s3-files-work)
3. [Key Concepts](#key-concepts)
4. [Key Features](#key-features)
5. [Architecture Overview](#architecture-overview)
6. [Prerequisites](#prerequisites)
7. [Hands-On Guide: Step-by-Step Setup](#hands-on-guide-step-by-step-setup)
   - [Step 1: Create an S3 Bucket with Required Settings](#step-1-create-an-s3-bucket-with-required-settings)
   - [Step 2: Create IAM Roles](#step-2-create-iam-roles)
   - [Step 3: Configure Security Groups](#step-3-configure-security-groups)
   - [Step 4: Install the S3 Files Client (amazon-efs-utils)](#step-4-install-the-s3-files-client-amazon-efs-utils)
   - [Step 5: Create the S3 File System](#step-5-create-the-s3-file-system)
   - [Step 6: Create Mount Targets](#step-6-create-mount-targets)
   - [Step 7: Mount the File System](#step-7-mount-the-file-system)
   - [Step 8: Test Read and Write Operations](#step-8-test-read-and-write-operations)
   - [Step 9: Persistent Mount via /etc/fstab](#step-9-persistent-mount-via-etcfstab)
8. [Mounting with Access Points](#mounting-with-access-points)
9. [Cross-VPC and Cross-Region Mounting](#cross-vpc-and-cross-region-mounting)
10. [How the Mount Helper Works](#how-the-mount-helper-works)
11. [Performance Observations](#performance-observations)
12. [Billing and Cost Model](#billing-and-cost-model)
13. [Best Practices](#best-practices)
14. [Troubleshooting](#troubleshooting)
15. [Clean Up](#clean-up)
16. [References](#references)

---

## What is Amazon S3 Files?

Amazon S3 Files is a brand-new AWS feature launched on **April 7, 2026**. It allows you to mount any S3 general-purpose bucket as a native NFS file system directly on your EC2 instances, containers, or Lambda functions — without any code changes or custom connectors.

For years, cloud architects faced a painful tradeoff: **S3** for scalable, durable, cost-effective object storage, or a **file system** (EFS/FSx) for interactive, mutable file access. You couldn't have both pointing at the same data. **S3 Files eliminates that tradeoff forever.**

With S3 Files, you get:

- **File system semantics** (read, write, rename, mkdir, permissions) on top of your S3 data
- **Sub-millisecond latency** for actively used files via a high-performance cache layer
- **Full two-way synchronization** — changes made through the file system sync back to S3, and changes made directly to S3 appear in the file system
- **No data duplication** — your authoritative data always remains in S3
- **NFS v4.1/4.2 protocol** — any application that works with EFS works here, zero code changes

No more `s3fs-fuse` workarounds. No more staging data to local disk before processing. No more choosing between object storage and file storage. **Your S3 bucket IS your file system.**

---

## How Does S3 Files Work?

When you create an S3 file system linked to your S3 bucket (or a prefix within it) and mount it on a compute resource, S3 Files performs the following:

1. **Presents a traversable view** of your bucket's objects as files and directories
2. **Loads data on demand** — as you navigate directories and open files, metadata and contents are placed onto the file system's high-performance storage. S3 Files does NOT duplicate your entire dataset
3. **Writes go to high-performance storage first**, then synchronize back to your S3 bucket (typically within ~60 seconds)
4. **Intelligent read routing** — small, frequently accessed files are served from the high-performance cache at sub-millisecond latency; large reads (≥1 MiB) stream directly from S3 at native GET throughput
5. **Automatic expiration** — data not read within a configurable window (1–365 days, default 30) automatically expires from the high-performance storage. Your data always remains safe in S3

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Your Application                             │
│                   (standard file I/O operations)                    │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ NFS v4.2 (TLS encrypted)
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     S3 File System                                   │
│              (High-Performance Storage Layer)                        │
│                                                                     │
│  • Sub-millisecond latency for active data                          │
│  • Automatic cache management                                       │
│  • POSIX permissions & file locking                                 │
└──────────┬──────────────────────────────────┬───────────────────────┘
           │ Export (writes → S3)             │ Import (S3 → file system)
           │ (~60 second sync)               │ (automatic detection)
           ▼                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        Amazon S3 Bucket                             │
│              (Authoritative source of truth)                        │
│                                                                     │
│  • 11 nines durability                                              │
│  • Standard S3 API access still works                               │
│  • Versioning enabled                                               │
│  • SSE-S3 or SSE-KMS encryption                                    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Key Concepts

| Term | Description |
|------|-------------|
| **File System** | A shared file system linked to your S3 bucket. Created via the S3 console or `aws s3files create-file-system` CLI command. |
| **High-Performance Storage** | The low-latency storage layer within your file system where actively used file data and metadata reside. S3 Files automatically manages this — copying data onto it when you access files and removing data that hasn't been read within the expiration window. |
| **Synchronization** | The process by which S3 Files keeps your data consistent between the file system and S3 bucket. **Importing** copies data from S3 onto the file system. **Exporting** copies file system changes back to S3. Both directions are automatic. |
| **Mount Target** | A network endpoint that provides access to your file system within a single Availability Zone in your VPC. You need at least one mount target, and can create a maximum of one per AZ. |
| **Access Point** | Application-specific entry points to a file system that simplify managing data access at scale. You can enforce user identities (UID/GID) and permissions for all requests through an access point. |

---

## Key Features

- **High Performance Without Full Data Replication** — Only your active working set is copied onto the high-performance storage, not your entire dataset. Small files get sub-millisecond latency; large reads stream directly from S3 at up to terabytes/second aggregate throughput.

- **Intelligent Read Routing** — S3 Files automatically routes reads to the optimal storage layer. Small random reads go to the high-performance cache; large sequential reads go directly to S3. Full file system semantics (consistency, locking, POSIX permissions) are maintained regardless.

- **Automatic Two-Way Synchronization** — Changes through the file system export to S3; changes made directly to S3 import into the file system. No manual sync commands needed.

- **Scalable Performance** — Throughput and IOPS scale automatically with your workload. No provisioning or capacity management required.

- **Encryption Everywhere** — All data in transit uses TLS. All data at rest uses AWS KMS keys (AWS-owned by default, or your own customer-managed keys).

- **NFS v4.1/4.2 Protocol** — Full file system semantics including read-after-write consistency, file locking, and POSIX permissions.

- **Supported Compute Services** — Amazon EC2, AWS Lambda, Amazon EKS, and Amazon ECS.

---

## Architecture Overview

```
                    ┌──────────────┐
                    │   S3 Bucket  │
                    │ (versioning  │
                    │  + SSE)      │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │  S3 File     │
                    │  System      │◄──── EventBridge (change detection)
                    │  (fs-xxxxx)  │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │  Mount   │ │  Mount   │ │  Mount   │
        │  Target  │ │  Target  │ │  Target  │
        │  (AZ-a)  │ │  (AZ-b)  │ │  (AZ-c)  │
        └────┬─────┘ └────┬─────┘ └────┬─────┘
             │            │            │
        ┌────▼─────┐ ┌────▼─────┐ ┌────▼─────┐
        │   EC2    │ │   EKS    │ │  Lambda  │
        │ Instance │ │   Pod    │ │ Function │
        └──────────┘ └──────────┘ └──────────┘
```

---

## Prerequisites

Before you begin, ensure the following are in place:

### AWS Account & Compute Setup

- An **AWS account** with IAM permissions to create S3 buckets, IAM roles, and S3 file systems
- An **EC2 instance** running Amazon Linux 2023 (Ubuntu/Debian also supported) in a VPC
- **AWS CLI v2.34 or newer** — older versions lack the `aws s3files` subcommand entirely
- An **S3 general-purpose bucket** with:
  - **Versioning enabled** (mandatory — S3 Files uses versioning for synchronization)
  - **Server-side encryption** using SSE-S3 or SSE-KMS (mandatory)

### Security Groups

| Security Group | Rule Type | Protocol | Port | Source/Destination |
|----------------|-----------|----------|------|--------------------|
| EC2 Instance | Outbound | TCP | 2049 | Mount target security group |
| Mount Target | Inbound | TCP | 2049 | EC2 instance security group |

### IAM Roles Required

You need **two** IAM roles:

1. **S3 Files Access Role** — assumed by `elasticfilesystem.amazonaws.com` to read/write your S3 bucket and manage EventBridge rules for change detection
2. **EC2 Instance Role** — attached to your EC2 instance to create/mount file systems and read S3 objects directly

### S3 Files Client

- **`amazon-efs-utils`** version 3.0.0 or above must be installed on your EC2 instance
- Includes the `mount.s3files` mount helper and CloudWatch monitoring support

---

## Hands-On Guide: Step-by-Step Setup

Set your bucket name and region as variables first. Every command in this guide uses `$BUCKET` and `$REGION`:

```bash
export BUCKET="my-s3files-bucket"
export REGION="us-east-1"
```

Replace with your desired bucket name and region.

---

### Step 1: Create an S3 Bucket with Required Settings

S3 Files requires both **versioning** and **server-side encryption** on the bucket. You cannot create a file system against a bucket that has either one disabled.

**Create the bucket:**

```bash
aws s3 mb s3://$BUCKET --region $REGION
```

**Enable versioning:**

```bash
aws s3api put-bucket-versioning \
  --bucket $BUCKET \
  --versioning-configuration Status=Enabled
```

**Configure default encryption with AES-256 and bucket keys:**

```bash
aws s3api put-bucket-encryption \
  --bucket $BUCKET \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'
```

**Verify versioning is active:**

```bash
aws s3api get-bucket-versioning --bucket $BUCKET
```

Expected output:

```json
{
    "Status": "Enabled"
}
```

---

### Step 2: Create IAM Roles

S3 Files needs **two IAM roles**. Getting the permissions wrong here is where most people get stuck.

#### A. S3 Files Access Role

This role is assumed by `elasticfilesystem.amazonaws.com`. It allows S3 Files to synchronize changes between your file system and S3 bucket, and manage EventBridge rules for change detection.

**Create the trust policy:**

```bash
cat > /tmp/s3files-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowS3FilesAssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "elasticfilesystem.amazonaws.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "aws:SourceAccount": "YOUR_ACCOUNT_ID"
        },
        "ArnLike": {
          "aws:SourceArn": "arn:aws:s3files:YOUR_REGION:YOUR_ACCOUNT_ID:file-system/*"
        }
      }
    }
  ]
}
EOF
```

**Create the role:**

```bash
aws iam create-role \
  --role-name S3FilesAccessRole \
  --assume-role-policy-document file:///tmp/s3files-trust-policy.json
```

**Create and attach the permission policy:**

```bash
cat > /tmp/s3files-access-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3BucketPermissions",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:ListBucketVersions"
      ],
      "Resource": "arn:aws:s3:::$BUCKET",
      "Condition": {
        "StringEquals": {
          "aws:ResourceAccount": "YOUR_ACCOUNT_ID"
        }
      }
    },
    {
      "Sid": "S3ObjectPermissions",
      "Effect": "Allow",
      "Action": [
        "s3:AbortMultipartUpload",
        "s3:DeleteObject*",
        "s3:GetObject*",
        "s3:List*",
        "s3:PutObject*"
      ],
      "Resource": "arn:aws:s3:::$BUCKET/*",
      "Condition": {
        "StringEquals": {
          "aws:ResourceAccount": "YOUR_ACCOUNT_ID"
        }
      }
    },
    {
      "Sid": "EventBridgeManage",
      "Effect": "Allow",
      "Action": [
        "events:DeleteRule",
        "events:DisableRule",
        "events:EnableRule",
        "events:PutRule",
        "events:PutTargets",
        "events:RemoveTargets"
      ],
      "Condition": {
        "StringEquals": {
          "events:ManagedBy": "elasticfilesystem.amazonaws.com"
        }
      },
      "Resource": ["arn:aws:events:*:*:rule/DO-NOT-DELETE-S3-Files*"]
    },
    {
      "Sid": "EventBridgeRead",
      "Effect": "Allow",
      "Action": [
        "events:DescribeRule",
        "events:ListRuleNamesByTarget",
        "events:ListRules",
        "events:ListTargetsByRule"
      ],
      "Resource": ["arn:aws:events:*:*:rule/*"]
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name S3FilesAccessRole \
  --policy-name S3FilesBucketAccess \
  --policy-document file:///tmp/s3files-access-policy.json
```

> **Note:** Replace `YOUR_ACCOUNT_ID` and `YOUR_REGION` with your actual AWS account ID and region throughout.

#### B. EC2 Instance Role

The instance role needs the managed `AmazonS3FilesClientFullAccess` policy plus permissions to pass the access role and manage network interfaces for mount targets.

**Attach the managed policy:**

```bash
aws iam attach-role-policy \
  --role-name MyEC2Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FilesClientFullAccess
```

**Create and attach the inline policy for PassRole, S3 Files, and EC2 network permissions:**

```bash
cat > /tmp/ec2-s3files-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "arn:aws:iam::YOUR_ACCOUNT_ID:role/S3FilesAccessRole"
    },
    {
      "Effect": "Allow",
      "Action": ["s3files:*", "elasticfilesystem:*"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeNetworkInterfaces",
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name MyEC2Role \
  --policy-name S3FilesEC2Access \
  --policy-document file:///tmp/ec2-s3files-policy.json
```

**Add the inline policy for direct S3 read access (required for intelligent read routing):**

```bash
cat > /tmp/ec2-s3-read-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3ObjectReadAccess",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:GetObjectVersion"],
      "Resource": "arn:aws:s3:::$BUCKET/*"
    },
    {
      "Sid": "S3BucketListAccess",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::$BUCKET"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name MyEC2Role \
  --policy-name S3DirectReadAccess \
  --policy-document file:///tmp/ec2-s3-read-policy.json
```

---

### Step 3: Configure Security Groups

Mount targets create elastic network interfaces (ENIs) in your VPC. The security group must accept NFS traffic (TCP 2049) from your EC2 instances.

**If your EC2 instance and mount target share the same security group:**

```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-example \
  --protocol tcp \
  --port 2049 \
  --source-group sg-example
```

**If they use different security groups**, replace `--source-group` with the EC2 instance's security group ID.

> ⚠️ **Warning:** The mount will hang silently if port 2049 is blocked. Double-check this before proceeding.

---

### Step 4: Install the S3 Files Client (amazon-efs-utils)

The `mount.s3files` helper is bundled with `amazon-efs-utils`.

**On Amazon Linux 2023:**

```bash
sudo yum install -y amazon-efs-utils
```

**On Ubuntu/Debian:**

```bash
curl https://amazon-efs-utils.aws.com/efs-utils-installer.sh | sudo sh -s -- --install
```

**Verify the mount helper is available:**

```bash
mount.s3files --version
```

Expected output: `3.0.0` or later.

---

### Step 5: Create the S3 File System

This maps a file system onto your bucket. The file system ID you get back is what you'll use for mounting.

```bash
aws s3files create-file-system \
  --region $REGION \
  --bucket arn:aws:s3:::$BUCKET \
  --role-arn arn:aws:iam::YOUR_ACCOUNT_ID:role/S3FilesAccessRole
```

**Example response:**

```json
{
    "fileSystemId": "fs-0abc123def456789",
    "bucket": "arn:aws:s3:::my-s3files-bucket",
    "status": "creating",
    "roleArn": "arn:aws:iam::123456789012:role/S3FilesAccessRole"
}
```

The file system takes **2–5 minutes** to become available. Poll the status:

```bash
aws s3files get-file-system \
  --file-system-id fs-0abc123def456789 \
  --region $REGION \
  --query "status" \
  --output text
```

Wait until the output shows `available` before continuing.

> **Console Alternative:** In the S3 console, select your bucket → **File systems** tab → **Create file system**. The console automatically creates mount targets in every AZ and an access point.

---

### Step 6: Create Mount Targets

A mount target is a network endpoint in your VPC. It **must be in the same Availability Zone** as your EC2 instance. You can only create one mount target per AZ per file system.

```bash
aws s3files create-mount-target \
  --file-system-id fs-0abc123def456789 \
  --subnet-id subnet-example \
  --security-groups sg-example \
  --region $REGION
```

**Example response:**

```json
{
    "mountTargetId": "mt-0a1b2c3d4e5f67890",
    "fileSystemId": "fs-0abc123def456789",
    "subnetId": "subnet-example",
    "ipv4Address": "10.0.1.142",
    "status": "creating"
}
```

This takes roughly **5 minutes** (it creates an ENI in your subnet). Poll the status:

```bash
aws s3files list-mount-targets \
  --file-system-id fs-0abc123def456789 \
  --region $REGION \
  --query "MountTargets[0].LifeCycleState" \
  --output text
```

Wait until it returns `available`.

> **Best Practice:** Create a mount target in **every Availability Zone** you operate in to reduce cross-AZ data transfer costs and improve availability.

---

### Step 7: Mount the File System

**Create the mount point:**

```bash
sudo mkdir -p /mnt/s3files
```

**Mount the file system:**

```bash
sudo mount -t s3files fs-0abc123def456789:/ /mnt/s3files
```

**Verify with `df`:**

```bash
df -h /mnt/s3files
```

Expected output:

```
Filesystem      Size  Used Avail Use% Mounted on
127.0.0.1:/     8.0E     0  8.0E   0% /mnt/s3files
```

> The 8.0E (8 exabytes) is the virtual size. Your actual storage lives in S3 and you pay S3 rates. The `127.0.0.1` source is expected — the NFS client connects through the local stunnel TLS proxy.

**Check mount details:**

```bash
findmnt -T /mnt/s3files
```

This confirms NFS 4.2 with TLS encryption, 1 MB read/write buffers, and hard mount semantics:

```
TARGET       SOURCE      FSTYPE OPTIONS
/mnt/s3files 127.0.0.1:/ nfs4   rw,relatime,vers=4.2,rsize=1048576,wsize=1048576,hard,proto=tcp,port=20563,timeo=600
```

**You can now use standard file system operations on your S3 data!**

```bash
ls /mnt/s3files
```

---

### Step 8: Test Read and Write Operations

**Upload a test file to S3 directly to verify two-way sync:**

```bash
echo "Hello from S3!" | aws s3 cp - s3://$BUCKET/test-from-s3.txt
```

**Read it from the mounted file system:**

```bash
cat /mnt/s3files/test-from-s3.txt
# Output: Hello from S3!
```

**Write from EC2 through the mount:**

```bash
echo "Written from EC2 via S3 Files" | sudo tee /mnt/s3files/hello-from-ec2.txt
```

**Create directories and nested files:**

```bash
sudo mkdir -p /mnt/s3files/app-data
echo "config_key=test_value" | sudo tee /mnt/s3files/app-data/config.txt
```

**Verify sync to S3** (wait ~60 seconds for export):

```bash
aws s3 ls s3://$BUCKET/ --recursive
```

Expected output:

```
2026-04-07 14:23:01         15 test-from-s3.txt
2026-04-07 14:25:33         31 hello-from-ec2.txt
2026-04-07 14:26:12         22 app-data/config.txt
```

> **Note:** Directories map to S3 prefixes. The `app-data/` directory becomes a prefix in the bucket.

---

### Step 9: Persistent Mount via /etc/fstab

To survive reboots, add the file system to `/etc/fstab`.

**Add the fstab entry:**

```bash
echo "fs-0abc123def456789:/ /mnt/s3files s3files _netdev,nofail 0 0" | sudo tee -a /etc/fstab
```

| Option | Purpose |
|--------|---------|
| `_netdev` | Tells the system to wait for networking before mounting. **Required** — without it, your instance may become unresponsive on boot. |
| `nofail` | Allows the instance to boot even if the file system fails to mount. **Recommended for production.** |

**Test the fstab entry:**

```bash
sudo umount /mnt/s3files
sudo mount -a
df -h /mnt/s3files
```

**With an access point:**

```bash
fs-0abc123def456789:/ /mnt/s3files s3files _netdev,nofail,accesspoint=fsap-0abc123 0 0
```

**With a subdirectory:**

```bash
fs-0abc123def456789:/path/to/directory /mnt/s3files s3files _netdev,nofail 0 0
```

---

## Mounting with Access Points

Access points are application-specific entry points that simplify managing data access at scale. You can enforce specific UID/GID and permissions for all requests through an access point.

**Mount using an access point:**

```bash
sudo mount -t s3files -o accesspoint=fsap-0abc123 fs-0abc123def456789 /mnt/s3files
```

---

## Cross-VPC and Cross-Region Mounting

### Mounting from Another VPC

When using VPC peering or a transit gateway, EC2 instances in one VPC can access S3 file systems in another VPC. You need to resolve the mount target manually using its IP address:

```bash
sudo mount -t s3files -o mounttargetip=10.0.1.142 fs-0abc123def456789 /mnt/s3files
```

> **Tip:** Always use a mount target IP in the same Availability Zone as your NFS client for high availability.

You can also use **Amazon Route 53** with a private hosted zone to resolve mount target IPs from another VPC automatically.

### Mounting from a Different AWS Region

If mounting from a VPC in a different region, edit the S3 Files configuration file first:

```bash
sudo vi /etc/amazon/efs/s3files-utils.conf
```

Uncomment and set the region where the file system is located:

```ini
region = us-east-1
```

Then mount using the mount target IP:

```bash
sudo mount -t s3files -o mounttargetip=10.0.1.142 fs-0abc123def456789 /mnt/s3files
```

---

## How the Mount Helper Works

When you issue a `mount -t s3files` command, the mount helper performs the following:

1. **Retrieves IAM credentials** from the EC2 instance profile
2. **Initializes the efs-proxy process** to establish a TLS-encrypted connection to the mount target
3. **Starts the amazon-efs-mount-watchdog** supervisor process to monitor TLS mount health
4. **Mounts the file system** at the specified mount point

The mount helper uses **TLS 1.2** with certificates signed by a trusted Amazon Certificate Authority. It also automatically applies these optimized mount options:

| Option | Value | Description |
|--------|-------|-------------|
| `nfsvers` | 4.2 | NFS protocol version |
| `rsize` | 1048576 | Max bytes per READ request (1 MB) for optimal performance |
| `wsize` | 1048576 | Max bytes per WRITE request (1 MB) for optimal performance |
| `hard` | — | NFS requests retry indefinitely until server replies (ensures data integrity) |
| `timeo` | 600 | Timeout of 60 seconds before retrying a request |
| `retrans` | 2 | Number of retries before further recovery |
| `noresvport` | — | Uses non-privileged TCP source port for uninterrupted availability after reconnection |

> **Note:** S3 Files always uses `tls` and `iam` mount options. TLS encryption and IAM authentication cannot be disabled.

---

## Performance Observations

Based on testing with an m5.xlarge instance in us-east-1:

| Test | Result |
|------|--------|
| 100 MB sequential write | 341 MB/s |
| 100 MB first read (cold) | 289 MB/s |
| 100 MB cached read | 4.7 GB/s |
| 10 MB write | 104 MB/s |
| Sync to S3 bucket | ~65 seconds |
| 5 concurrent file writes | 0.041 seconds |

**Key takeaways:**

- **Cached reads are extremely fast** — files recently written or read serve from the local cache at memory-like speeds (4.7 GB/s)
- **Cold reads** of files >1 MB stream directly from S3 at native GET throughput — no S3 Files storage charges for those reads
- **The ~65 second sync delay** is the main thing to plan around. If another service needs to read a file from S3 immediately after a write, account for this lag
- **Writes land in the cache first** with sub-millisecond latency, then sync back to S3

---

## Billing and Cost Model

S3 Files billing has three components:

| Component | What You Pay For |
|-----------|-----------------|
| **High-Performance Storage** | Storage rate for the fraction of active data resident on the high-performance cache |
| **File System Access Charges** | Reading from and writing to the high-performance storage |
| **Standard S3 Costs** | Your underlying S3 storage, requests, and data transfer as usual |

**Cost-saving details:**

- Large reads (≥1 MiB) stream directly from S3 even when data also resides on the high-performance storage — you pay only the standard S3 GET request cost with **no file system access charge**
- Data not read within the expiration window (default 30 days) automatically expires from the high-performance storage, reducing costs
- Synchronization operations: importing data incurs write charges; exporting changes incurs read charges

For current pricing, see the [S3 Files pricing page](https://aws.amazon.com/s3/pricing/).

---

## Best Practices

### Performance and Cost Optimization

- **Parallelize your workloads** — S3 Files supports highly parallel workloads. Distribute reads across multiple files and compute instances. You can also create multiple file systems scoped to different prefixes within the same bucket to scale horizontally.

- **Scope your file system to the smallest prefix your workload needs** — S3 has no native concept of directories. Renaming directories with millions of files requires writing new objects and deleting originals for every file, increasing S3 request costs and sync time.

- **Use large I/O sizes** — S3 Files meters each read/write at a minimum of 32 KB. Using 1 MB or larger I/O sizes amortizes per-operation overhead and is more cost effective.

- **Tune your `sizeLessThan` value** — By default, S3 Files caches data for files <128 KB on first access. If your workload needs low-latency reads on larger files, increase this threshold.

- **Set expiration windows to match your workload** — Short-lived workloads (batch jobs, training runs): use 1–7 days. Workloads that revisit data over weeks: use 30–90 days.

- **Create a mount target in every AZ** — Reduces cross-AZ data transfer costs and improves performance and availability.

### Synchronization

- **Understand the consistency model** — When a file is modified through the file system AND its corresponding S3 object changes simultaneously, S3 Files treats the **S3 bucket as the source of truth** and moves the conflicting file to the lost-and-found directory. **Designate one path (file system or S3) as the primary writer.**

- **Monitor synchronization health** — Use CloudWatch metrics to track `PendingExports` (growing = changes faster than sync rate) and `ExportFailures` (non-zero = files that need attention).

### Access Control

- **Follow least privilege** — Use `AmazonS3FilesClientReadOnlyAccess` for read-only workloads instead of `AmazonS3FilesClientFullAccess`. Scope file systems to specific prefixes.

- **Do NOT modify the S3 Files IAM role** — Changing or removing it breaks synchronization.

- **Do NOT modify the S3 Files EventBridge rule** — Rules prefixed with `DO-NOT-DELETE-S3-Files` detect bucket changes. Removing them causes your file system to become stale.

- **Restrict access to efs-utils logs** — `efs-utils` writes S3 object key names in logs at `/var/log/amazon/efs`. If key names contain sensitive info: `sudo chmod 700 /var/log/amazon/efs`

### Monitoring

- **Set CloudWatch alarms** on `ImportFailures` and `ExportFailures` to be notified when files fail to synchronize. Failed exports may indicate permission issues, encryption key problems, or path length limits.

---

## Troubleshooting

### Mount Command Fails

| Error | Cause | Fix |
|-------|-------|-----|
| `mount.s3files: command not found` | S3 Files client not installed or below v3.0.0 | Install/upgrade `amazon-efs-utils` |
| `Failed to resolve file system DNS name` | No mount target in the EC2 instance's AZ | Create a mount target in that AZ |
| Connection timed out | Security group blocking NFS traffic | Verify TCP 2049 is allowed between EC2 and mount target security groups |
| `Access denied` during mount | Missing IAM permissions | Attach `AmazonS3FilesClientFullAccess` or add `s3files:ClientMount` permission |
| botocore not installed | Mount helper dependency missing | Install botocore per the amazon-efs-utils README |

### Permission Denied on File Operations

| Symptom | Cause | Fix |
|---------|-------|-----|
| Can read but not write | Missing `s3files:ClientWrite` permission | Attach `AmazonS3FilesClientFullAccess` managed policy |
| Permission errors on root-owned files | Missing `s3files:ClientRootAccess` | Add `s3files:ClientRootAccess` to your policy |
| Access denied despite correct IAM | File system policy denying access | Check file system policy for explicit denies |
| POSIX permission mismatch | Application UID/GID doesn't match file owner | Use an access point to enforce specific UID/GID |

### Intelligent Read Routing Not Working

- **Missing S3 inline policy on compute role** — The IAM role must include `s3:GetObject` and `s3:GetObjectVersion` on the linked bucket. Without this, all reads go through the file system instead of directly from S3.
- **S3 bucket not reachable** — Check the `S3BucketReachable` CloudWatch metric. Verify VPC endpoint or NAT gateway access to S3.
- **File has been modified** — Reads only go directly to S3 when the file hasn't been modified through the file system. Wait for sync to complete.

### Missing Object in S3 After File System Write

S3 Files batches changes for ~60 seconds before exporting to S3. If the object still doesn't appear, check the export status:

```bash
getfattr -n "user.s3files.status;$(date -u +%s)" missing-file.txt --only-values
```

Common `ExportError` values:

| Error | Cause |
|-------|-------|
| `S3AccessDenied` | IAM role lacks permissions to write to S3 |
| `S3BucketNotFound` | Bucket no longer exists or was renamed |
| `PathTooLong` | File path exceeds S3 key length limit |
| `EncryptionKeyInaccessible` | KMS key inaccessible to S3 Files |
| `FileSizeExceedsS3Limit` | File exceeds S3 object size limit |
| `RoleAssumptionFailed` | Trust policy misconfigured |
| `S3ObjectArchived` | Object is in Glacier; restore it first |

### Files Appearing in the Lost-and-Found Directory

This occurs when a **synchronization conflict** arises — the same file is modified through the file system AND the corresponding S3 object changes before sync completes. S3 Files treats S3 as the source of truth and moves the conflicting file to `.s3files-lost+found-{file-system-id}`.

**Inspect the file:**

```bash
getfattr -n "user.s3files.status;$(date -u +%s)" \
  .s3files-lost+found-fs-12345678/abcdef1234_report.csv --only-values
```

> **Note:** Files in lost-and-found remain indefinitely and count toward storage costs. Delete them when no longer needed.

### Synchronization Falling Behind

If `PendingExports` CloudWatch metric is growing, your workload is generating changes faster than the sync rate. S3 Files exports up to **800 files per second per file system**. Consider reducing the rate of modifications or distributing work across multiple file systems.

### Enabling Debug Logs

**Mount helper and watchdog logs** — Edit `/etc/amazon/efs/s3files-utils.conf`:

```ini
[DEFAULT]
logging_level = DEBUG
```

**Proxy (efs-proxy) logs:**

```ini
[proxy]
proxy_logging_level = DEBUG
```

**TLS tunnel (stunnel) logs:**

```ini
[mount]
stunnel_debug_enabled = true
stunnel_logs_file = /var/log/amazon/efs/{fs_id}.stunnel.log
```

Unmount and remount for changes to take effect. Logs are written to `/var/log/amazon/efs/`.

**Collect logs for AWS Support:**

```bash
sudo tar -czf /tmp/s3files-support-logs.tar.gz \
  /var/log/amazon/efs/ \
  /etc/amazon/efs/s3files-utils.conf
```

---

## Clean Up

To avoid ongoing charges, tear down resources in reverse order:

**1. Unmount the file system:**

```bash
sudo umount /mnt/s3files
```

**2. Remove the fstab entry:**

```bash
sudo sed -i '/s3files/d' /etc/fstab
```

**3. Delete the mount target:**

```bash
aws s3files delete-mount-target \
  --mount-target-id mt-0a1b2c3d4e5f67890 \
  --region $REGION
```

Wait a few minutes for deletion to complete.

**4. Delete the file system:**

```bash
aws s3files delete-file-system \
  --file-system-id fs-0abc123def456789 \
  --region $REGION
```

**5. Clean up IAM roles (if no longer needed):**

```bash
aws iam delete-role-policy --role-name S3FilesAccessRole --policy-name S3FilesBucketAccess
aws iam delete-role --role-name S3FilesAccessRole
```

> **Note:** The S3 bucket and its data remain untouched after cleanup.

---

## References

- [AWS Official: Working with Amazon S3 Files](https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-files.html)
- [AWS Official: Tutorial — Getting Started with S3 Files](https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-files-getting-started.html)
- [AWS Official: Mounting S3 File Systems on Amazon EC2](https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-files-mounting.html)
- [AWS Official: Prerequisites for S3 Files](https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-files-prereq-policies.html)
- [AWS Official: S3 Files Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-files-best-practices.html)
- [AWS Official: Troubleshooting S3 Files](https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-files-troubleshooting.html)
- [AWS Official: S3 Files Pricing](https://aws.amazon.com/s3/pricing/)
- [ComputingForGeeks: Mount S3 Bucket on EC2 with Amazon S3 Files (NFS)](https://computingforgeeks.com/mount-s3-buckets-file-system-s3-files-ec2/)

> **Content was rephrased for compliance with licensing restrictions.** Information sourced from AWS official documentation and community guides, reorganized and rewritten for this hands-on practical guide.
