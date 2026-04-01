# AWS Portfolio Infrastructure

Personal portfolio website deployed on AWS using Terraform and GitHub Actions.

## Architecture

```
                        ┌─────────────────────────────────────────────┐
                        │            VPC  (10.0.0.0/16)              │
                        │                                             │
  ┌──────────┐          │  ┌───────────────┐   ┌───────────────┐     │
  │ Internet │────80───▶│  │ Public Subnet │   │ Public Subnet │     │
  └──────────┘          │  │ 10.0.1.0/24   │   │ 10.0.2.0/24   │     │
                        │  │ (us-east-1a)  │   │ (us-east-1b)  │     │
                        │  └───────┬───────┘   └───────┬───────┘     │
                        │          │   ┌───────────┐   │             │
                        │          └───│    ALB    │───┘             │
                        │              └─────┬─────┘                 │
                        │            ┌───────┴───────┐               │
                        │      ┌─────┴─────┐   ┌────┴──────┐        │
                        │      │ EC2 Nginx │   │ EC2 Nginx │        │
                        │      │ (t3.micro)│   │ (t3.micro)│        │
                        │      └───────────┘   └───────────┘        │
                        └─────────────────────────────────────────────┘

                        EC2 instances pull website from S3 on boot
                        ┌───────────┐
                        │  S3 Bucket│ ← website files (HTML, CSS)
                        └───────────┘
```

## AWS Services Used

| Service | Purpose |
|---------|---------|
| **VPC** | Isolated network with custom CIDR (10.0.0.0/16) |
| **Subnets** | 2 public subnets across 2 AZs for high availability |
| **Security Groups** | ALB accepts port 80 from internet; EC2 accepts port 80 from ALB only |
| **ALB** | Application Load Balancer distributes traffic across EC2 instances |
| **Auto Scaling Group** | Manages EC2 fleet (min: 1, max: 2), replaces unhealthy instances |
| **EC2** | t3.micro (free tier eligible) running Nginx |
| **S3** | Stores website files; EC2 pulls content on boot |
| **IAM** | Instance profile allows EC2 to read from S3 (least privilege) |

## Project Structure

```
portfolio-infra/
├── terraform/
│   ├── providers.tf            # AWS provider + optional S3 remote state
│   ├── variables.tf            # Input variables with defaults
│   ├── main.tf                 # Wires networking + compute modules
│   ├── outputs.tf              # ALB URL, S3 bucket name, VPC ID
│   └── modules/
│       ├── networking/         # VPC, subnets, security groups
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── compute/            # S3, IAM, ALB, Launch Template, ASG
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
├── website/                    # Portfolio site (HTML + CSS)
│   ├── index.html
│   └── css/style.css
├── .github/workflows/
│   └── deploy.yml              # Syncs website to S3 on push
└── .gitignore
```

## Security Design

Traffic flows through a security group chain:

```
Internet ──[port 80]──▶ ALB (SG: allow 80 from 0.0.0.0/0)
                          │
                     [port 80]
                          │
                          ▼
                        EC2 (SG: allow 80 from ALB SG only)
```

- EC2 instances are **not directly reachable** from the internet — traffic must go through the ALB
- IAM role follows **least privilege** — EC2 can only `s3:GetObject` and `s3:ListBucket` on its own bucket
- No SSH access configured (no port 22) — infrastructure is immutable
- All resources tagged with `ManagedBy = Terraform` for audit trail

## Prerequisites

- AWS account (free tier eligible)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials

## Quick Start

```bash
# 1. Clone and navigate to terraform directory
git clone https://github.com/mohamedshafims/portfolio-infra.git
cd portfolio-infra/terraform

# 2. Initialize Terraform (downloads providers and modules)
terraform init

# 3. Review what will be created
terraform plan

# 4. Deploy infrastructure
terraform apply

# 5. Upload website files to S3
aws s3 sync ../website/ s3://$(terraform output -raw s3_bucket_name)/website/

# 6. Access your site (wait 2-3 min for health checks to pass)
echo "Visit: $(terraform output -raw website_url)"
```

## Tear Down

```bash
# Destroy all AWS resources (avoids ongoing charges)
cd terraform
terraform destroy
```

## Cost

| Resource | Free Tier | Notes |
|----------|-----------|-------|
| EC2 t3.micro | 750 hrs/month (12 months) | Free if account < 12 months old |
| S3 | 5 GB storage | Website files are a few KB |
| ALB | **Not free tier** | ~$16/month — deploy/test/destroy to avoid charges |
| VPC, subnets, SGs | Free | No charge for networking constructs |
| IAM | Free | No charge for roles/policies |

**Recommendation:** Deploy, verify it works, then `terraform destroy`. Re-deploy when needed.

## Architecture Decisions

- **Modular Terraform** — Networking and compute are separate modules for reusability and separation of concerns
- **Community VPC module** — Battle-tested by thousands of users, avoids writing 100+ lines of raw VPC resources
- **EC2 in public subnets** — NAT Gateway costs ~$32/month; EC2 needs internet for `dnf install nginx`; acceptable for this project
- **S3 for content** — Decouples website content from infrastructure; update website without rebuilding EC2
- **No CloudFront** — ALB already provides HTTP endpoint; CloudFront would add HTTPS + CDN but increases complexity
- **S3 native state locking** — Terraform 1.10+ supports lock files in S3 without DynamoDB (noted in providers.tf)

## What I Learned

- VPC networking: CIDR design, public vs private subnets, route tables, Internet Gateway
- Security groups as stateful firewalls with SG-to-SG references
- ALB + ASG integration for self-healing and load distribution
- IAM roles and instance profiles for service-to-service access
- Terraform modules for DRY, reusable infrastructure code
- GitHub Actions for CI/CD pipeline automation
