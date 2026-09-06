terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─── Networking ────────────────────────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "medaid-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
  tags                    = { Name = "medaid-public-subnet" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "medaid-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ─── Security Group ─────────────────────────────────────────────────────────

resource "aws_security_group" "medaid_sg" {
  name        = "medaid-sg"
  description = "Allow HTTP, HTTPS, and SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ─── Key Pair ────────────────────────────────────────────────────────────────

resource "aws_key_pair" "deployer" {
  key_name   = "medaid-deployer-key"
  public_key = file("${path.module}/deploy_key.pub")
}

# ─── AMI (Deep Learning AMI — has NVIDIA drivers + Docker pre-installed) ────

data "aws_ami" "deep_learning" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Deep Learning Base OSS Nvidia Driver GPU AMI (Ubuntu 22.04) *"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# ─── EC2 User Data (writes .env and starts the stack) ────────────────────────

locals {
  user_data = <<-USERDATA
    #!/bin/bash
    set -e
    exec > /var/log/medaid-startup.log 2>&1

    echo "=== MedAid startup: $(date) ==="

    # Wait for apt locks
    while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 \
       || sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
      sleep 5
    done

    apt-get update -y
    apt-get install -y git

    # docker-compose v2 plugin (DL AMI has Docker but may lack Compose v2)
    if ! docker compose version &>/dev/null; then
      curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
        -o /usr/local/bin/docker-compose
      chmod +x /usr/local/bin/docker-compose
      ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    fi

    # Clone the mono-repo that has all service submodules
    APP_DIR=/home/ubuntu/medaid
    mkdir -p "$APP_DIR"
    cd "$APP_DIR"

    git clone --recursive https://github.com/sfe-gp-2-project-2-26/first-aid-local-dev.git app
    cd app

    # Write the production .env file
    cat > .env <<ENV
    GEMINI_API_KEY=${var.gemini_api_key}
    GROQ_API_KEY=${var.groq_api_key}
    JWT_SECRET_KEY=${var.jwt_secret_key}
    ENV

    # Copy in the production docker-compose and Caddyfile
    cat > docker-compose.prod.yml <<'COMPOSE'
    ${file("${path.module}/docker-compose.prod.yml.tpl")}
    COMPOSE

    cat > Caddyfile <<'CADDY'
    ${file("${path.module}/Caddyfile")}
    CADDY

    # Build and start everything
    docker compose -f docker-compose.prod.yml up -d --build

    echo "=== MedAid startup complete: $(date) ==="
  USERDATA
}

# ─── EC2 Instance ────────────────────────────────────────────────────────────

resource "aws_instance" "medaid_server" {
  ami                    = data.aws_ami.deep_learning.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.medaid_sg.id]

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

  user_data = local.user_data

  tags = { Name = "medaid-production-server" }
}

# ─── Elastic IP ──────────────────────────────────────────────────────────────

resource "aws_eip" "medaid_eip" {
  instance = aws_instance.medaid_server.id
  domain   = "vpc"
}

# ─── Route 53 DNS ────────────────────────────────────────────────────────────

data "aws_route53_zone" "main" {
  zone_id = var.hosted_zone_id
}

resource "aws_route53_record" "medaid" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  records = [aws_eip.medaid_eip.public_ip]
}
