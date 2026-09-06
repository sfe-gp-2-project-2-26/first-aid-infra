# MedAid Infrastructure

Single-instance GPU deployment on AWS using Terraform + Docker Compose + Caddy.

## Architecture

```
Internet
  ↓
AWS Elastic IP (static)
  ↓
EC2 g4dn.xlarge (Deep Learning AMI Ubuntu 22.04)
  ↓ Docker Compose
  ├─ Caddy (port 80/443, auto-HTTPS via Let's Encrypt)
  ├─ Frontend (TanStack Start SSR, port 8080)
  ├─ Auth Service (Node.js/Express, port 4000)
  ├─ AI Service (FastAPI, port 3000)
  ├─ Map Service (FastAPI, port 5000)
  ├─ BGE Service (FastAPI + NVIDIA GPU, port 8000)
  ├─ MongoDB (port 27017, local volume)
  └─ Qdrant (port 6333, local volume)
```

## One-Time Setup

### 1. Prerequisites
- AWS CLI configured (`aws configure`)
- Terraform installed

### 2. Generate Deploy Key (already done — keep `deploy_key` safe)
```bash
ssh-keygen -t rsa -b 4096 -f deploy_key -N ""
```

### 3. Deploy Infrastructure
```bash
terraform init
terraform apply
```

That's it. Terraform will:
- Create the VPC, subnet, security group
- Upload `deploy_key.pub` as an AWS Key Pair
- Launch a `g4dn.xlarge` Deep Learning AMI instance
- Assign an Elastic IP
- Point `medaid.abdallahgabr.me` at the Elastic IP
- Bootstrap the server: clone repos, write secrets, start Docker Compose

### 4. After `terraform apply` completes

The server will continue bootstrapping in the background (~5-10 min for first docker build).
Watch progress with:
```bash
ssh -i deploy_key ubuntu@<ELASTIC_IP> 'sudo tail -f /var/log/medaid-startup.log'
```

Then visit: **https://medaid.abdallahgabr.me**

## CI/CD (GitHub Actions)

On every push to `main`, the workflow:
1. SSHes into the server
2. Pulls latest submodule code
3. Rebuilds changed Docker images
4. Restarts the stack

### Required GitHub Secrets (set in first-aid-infra repo settings)
| Secret | Value |
|--------|-------|
| `SSH_PRIVATE_KEY` | Contents of `deploy_key` file |
| `SERVER_IP` | Elastic IP from `terraform output instance_public_ip` |
| `GEMINI_API_KEY` | Your Gemini API key |
| `GROQ_API_KEY` | Your Groq API key |
| `JWT_SECRET_KEY` | Any strong random string |

## Teardown
```bash
terraform destroy
```
