# Oracle Cloud Deployment Checklist

## Part 1: Local Setup (You do this on your machine)
- [x] SSH key already created and saved to `~/.ssh/oracle_vm_key`
- [x] `.env.oracle` file created with your credentials
- [x] Deployment scripts already in place and executable

## Part 2: GitHub Secrets Setup (You do this in GitHub)
Add these secrets to your repository: https://github.com/YOUR_USERNAME/web-messenger/settings/secrets/actions

**Scripts expects these secrets:**
- `ORACLE_HOST` = `89.168.94.114` (your VM's public IP)
- `ORACLE_USER` = `ubuntu`
- `ORACLE_SSH_KEY` = (contents of `~/.ssh/oracle_vm_key` - copy paste the entire private key)
- `ORACLE_SSH_PORT` = `22`
- `ORACLE_APP_PATH` = `/home/ubuntu/web-messenger`
- `ORACLE_APP_URL` = `http://89.168.94.114`

**How to get the SSH key content:**
```bash
cat ~/.ssh/oracle_vm_key
```
Then copy the entire output and paste it as the `ORACLE_SSH_KEY` secret.

## Part 3: Server Bootstrap (You do this via SSH on the Oracle VM)

### Step 1: Connect to your VM
```bash
ssh -i ~/.ssh/oracle_vm_key ubuntu@89.168.94.114
```

### Step 2: Clone your repo & run bootstrap (on the VM)
```bash
sudo apt-get update -y
sudo apt-get install -y git
git clone https://github.com/YOUR_USERNAME/web-messenger.git
cd web-messenger
chmod +x scripts/deploy/oracle_bootstrap.sh
./scripts/deploy/oracle_bootstrap.sh
newgrp docker  # or log out and log back in
```

The bootstrap script installs:
- Docker
- Firewall rules for ports 22, 80, 443

### Step 3: Copy the .env.oracle file to the VM
From your local machine:
```bash
scp -i ~/.ssh/oracle_vm_key /home/katikraavi/web-messenger/.env.oracle ubuntu@89.168.94.114:web-messenger/.env.oracle
```

### Step 4: Deploy the application (on the VM)
```bash
cd ~/web-messenger
./scripts/deploy/oracle_deploy.sh
```

The deploy script will:
- Build the Docker image with your app
- Start the container
- Expose port 80 to the internet

### Step 5: Verify deployment
From your local machine or browser:
```bash
curl http://89.168.94.114/health
```

If 200, you're live. Access frontend at: http://89.168.94.114

## Part 4: Ongoing Deployments (Auto via GitHub)
After this initial setup, every `git push` to `main` will:
1. SSH into your Oracle VM
2. Pull latest code
3. Run deploy script
4. Restart app automatically

 You don't need to do anything except push your code.

## Troubleshooting

**SSH connection refused:**
- Verify ingress rule allows port 22 in Oracle Console
- Check public IP is actually assigned (not "Not Assigned")

**Docker command not found:**
- You need to do `newgrp docker` after bootstrap, or log out and back in

**Port 80 not accessible:**
- Check ingress rule for port 80 in Oracle Console
- Or wait ~30 seconds for health check to start

**Container crashes:**
- SSH to VM and run: `docker logs web-messenger-app`
