#!/usr/bin/env bash
set -euo pipefail

echo "[1/5] Updating apt cache"
sudo apt-get update -y

echo "[2/5] Installing Docker and Compose plugin"
sudo apt-get install -y ca-certificates curl gnupg lsb-release
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "[3/5] Enabling Docker service"
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker "$USER" || true

echo "[4/5] Opening firewall ports 80/443/22"
sudo apt-get install -y ufw
sudo ufw allow 22/tcp || true
sudo ufw allow 80/tcp || true
sudo ufw allow 443/tcp || true
sudo ufw --force enable || true

echo "[5/5] Done"
echo "Re-login (or run: newgrp docker) before running deploy script."
