#!/bin/bash
set -e

echo "Waiting for apt/dpkg locks..."
while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 || sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    echo "Waiting for other software managers to finish..."
    sleep 5
done

echo "Installing updates and required packages..."
sudo apt-get update
sudo apt-get install -y git jq curl

# Deep Learning AMI should already have docker and nvidia-docker. Let's verify.
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
fi

if ! command -v docker-compose &> /dev/null; then
    echo "Installing docker-compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

sudo systemctl enable docker
sudo systemctl start docker

sudo usermod -aG docker ubuntu

# Ensure NVIDIA runtime is default if GPUs are present (already set up in DL AMI usually, but good to check)
# We can skip modifying daemon.json since the DL AMI handles it.

echo "Setting up application directory..."
mkdir -p /home/ubuntu/medaid
cd /home/ubuntu/medaid

echo "Cloning repositories..."
if [ ! -d "first-aid-local-dev" ]; then
    git clone --recursive https://github.com/sfe-gp-2-project-2-26/first-aid-local-dev.git
else
    cd first-aid-local-dev
    git pull origin main
    git submodule update --init --recursive
    cd ..
fi

cd first-aid-local-dev

# Ensure we have the production docker-compose and Caddyfile
cp /tmp/docker-compose.prod.yml ./docker-compose.prod.yml
cp /tmp/Caddyfile ./Caddyfile

echo "Starting Docker Compose..."
# Stop existing just in case
sudo docker-compose -f docker-compose.prod.yml down || true

# Start with build
sudo docker-compose -f docker-compose.prod.yml up -d --build

echo "Deployment completed successfully!"
