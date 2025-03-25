# CP-Planta CLI Commands Reference

This document provides a standardized reference for all command-line tools available in the CP-Planta infrastructure project. Use this as a quick reference when working with the deployment scripts.

## Table of Contents

- [Environment Management](#environment-management)
- [Deployment Commands](#deployment-commands)
- [Infrastructure Management](#infrastructure-management)
- [Service Management](#service-management)
- [DNS Management](#dns-management)
- [Native CLI Commands](#native-cli-commands)
- [CI/CD Commands](#cicd-commands)
- [Common Error Codes](#common-error-codes)

## Environment Management

### secrets-manager.sh

Manages sensitive configuration data securely.

```bash
# Create a template .env file
./secrets-manager.sh template

# Check if all required secrets are present
./secrets-manager.sh check

# Encrypt your .env file with a password
./secrets-manager.sh encrypt -p "your-secure-password"

# Decrypt your .env.encrypted file
./secrets-manager.sh decrypt -p "your-secure-password"

# Specify alternate input file
./secrets-manager.sh check -f .env.staging
```

## Deployment Commands

### deploy.sh

Primary script for infrastructure provisioning and application deployment.

```bash
# Deploy to AWS
./deploy.sh --provider aws

# Deploy to Azure
./deploy.sh --provider azure

# Skip Terraform provisioning
./deploy.sh --provider aws --skip-terraform

# Non-interactive deployment
./deploy.sh --provider aws --no-interactive
```

### update-deployment.sh

Updates existing infrastructure and services without full redeployment.

```bash
# Update all services
./update-deployment.sh --provider aws

# Update only frontend services
./update-deployment.sh --provider aws --service frontend

# Update only backend services
./update-deployment.sh --provider aws --service backend

# Update only database services
./update-deployment.sh --provider aws --service db

# Update infrastructure with Terraform
./update-deployment.sh --provider aws --infra

# Force update all services
./update-deployment.sh --provider aws --service all --force
```

## Infrastructure Management

### check-existing-resources.sh

Identifies and manages existing cloud resources that might conflict with deployment.

```bash
# Check for existing AWS resources
./check-existing-resources.sh --provider aws --action check

# Import existing resources into Terraform state
./check-existing-resources.sh --provider aws --action import

# Delete existing resources
./check-existing-resources.sh --provider aws --action delete
```

### save-terraform-state.sh

Manages Terraform state files for team collaboration.

```bash
# Save state to S3
./save-terraform-state.sh --provider aws --action save --storage s3

# Save state to Azure Blob
./save-terraform-state.sh --provider azure --action save --storage azure

# Save state to GitHub
./save-terraform-state.sh --provider aws --action save --storage github

# Load state from S3
./save-terraform-state.sh --provider aws --action load --storage s3
```

### destroy.sh

Destroys infrastructure to avoid ongoing cloud charges.

```bash
# Destroy AWS infrastructure
./destroy.sh --provider aws

# Destroy Azure infrastructure
./destroy.sh --provider azure

# Use specific state file
./destroy.sh --provider aws --state ./path/to/terraform.tfstate

# Auto-approve destruction (no confirmation)
./destroy.sh --provider aws --yes
```

## Service Management

These commands should be run on the Swarm manager node after connecting via SSH.

### Deployment Management

```bash
# Deploy or update the stack
docker stack deploy --with-registry-auth -c /home/ubuntu/stack.yml CP-Planta

# Remove the stack
docker stack rm CP-Planta
```

### Service Operations

```bash
# List all services
docker service ls

# View service details
docker service inspect CP-Planta_backend

# View service logs
docker service logs CP-Planta_backend

# View service logs with timestamps and follow
docker service logs -f --timestamps CP-Planta_backend
```

### Scaling Operations

```bash
# Scale a service
docker service scale CP-Planta_backend=3

# Scale multiple services
docker service scale CP-Planta_backend=3 CP-Planta_frontend=2
```

### Service Updates

```bash
# Update service image
docker service update --image norohim/cp-planta-backend:latest CP-Planta_backend

# Force update/recreate service
docker service update --force CP-Planta_backend

# Add environment variable
docker service update --env-add "DEBUG=true" CP-Planta_backend
```

### Swarm Management

```bash
# List all nodes
docker node ls

# List tasks on all nodes
docker node ps $(docker node ls -q)

# Node maintenance mode
docker node update --availability drain <node-id>

# Return node to active state
docker node update --availability active <node-id>
```

## DNS Management

### duckdns-updater.sh (Currently integrated into deploy.sh as a post-deployment step) 

Updates DuckDNS records with your current public IP address

```bash
# Update DuckDNS records
./duckdns-updater.sh (deprecated) 
```

### DNS Verification

```bash
# Check DNS propagation
dig cpplanta.duckdns.org

# Check internal CoreDNS resolution (from Swarm manager)
docker exec $(docker ps -q -f name=dns) dig @localhost cpplanta.duckdns.org
```

## Native CLI Commands

### Terraform Commands

Direct Terraform commands for advanced operations:

```bash
# Initialize Terraform
cd TerraformAWS
terraform init

# See planned changes
terraform plan

# Apply changes
terraform apply

# See current state
terraform state list

# Import existing resource
terraform import aws_instance.instance[\"instance1\"] i-1234567890abcdef0

# Remove resource from state
terraform state rm aws_instance.instance[\"instance1\"]
```

### Ansible Commands

Direct Ansible commands for advanced operations:

```bash
# Ping all nodes
ansible -i static_ip.ini all -m ping

# Check Docker service status
ansible -i static_ip.ini all -m shell -a "systemctl status docker"

# Run only specific tasks from playbook
ansible-playbook -i static_ip.ini deployment/ansible/playbooks/swarm_setup.yml --tags "docker"

# Run playbook with verbose output
ansible-playbook -i static_ip.ini deployment/ansible/playbooks/swarm_setup.yml -vvv
```

### AWS CLI Commands

```bash
# List EC2 instances
aws ec2 describe-instances --query 'Reservations[].Instances[].{ID:InstanceId,Name:Tags[?Key==`Name`].Value|[0],State:State.Name,IP:PublicIpAddress}' --output table

# Get VPC info
aws ec2 describe-vpcs --query 'Vpcs[].{VpcId:VpcId,CidrBlock:CidrBlock,Name:Tags[?Key==`Name`].Value|[0]}' --output table

# Check security group rules
aws ec2 describe-security-groups --group-id <sg-id> --query 'SecurityGroups[].IpPermissions[]' --output table
```

### Azure CLI Commands

```bash
# List VMs
az vm list --output table

# Check VM status
az vm get-instance-view --name <vm-name> --resource-group cp-planta-ages --query instanceView.statuses[1] --output table

# Get public IPs
az network public-ip list --query "[].{Name:name,IPAddress:ipAddress,Status:provisioningState}" --output table
```

## CI/CD Commands

### GitHub Actions

```bash
# List workflows
gh workflow list

# Run a workflow
gh workflow run full_deployment.yml -f provider=aws -f environment=production

# View workflow runs
gh run list --workflow=full_deployment.yml

# View logs of a workflow run
gh run view <run-id>

# Download artifacts from a run
gh run download <run-id>
```

## Common Error Codes

| Error Code/Message | Possible Cause | Solution |
|-------------------|----------------|----------|
| `SSH permission denied` | Incorrect key permissions | `chmod 400 ssh_keys/*.pem` |
| `No space left on device` | Disk space issue on node | Clean up old images: `docker system prune -a` |
| `Unable to connect to the server` | Security group misconfiguration | Check inbound rules for ports 22, 80, 443 |
| `Terraform state locked` | Previous operation interrupted | `terraform force-unlock <lock-id>` |
| `Swarm node not ready` | Docker daemon issue | Restart Docker: `systemctl restart docker` |
| `502 Bad Gateway` | Service not running or Traefik issue | Check service status and logs |
| `Let's Encrypt rate limit` | Too many certificate requests | Use staging ACME server or wait for limit reset |
| `ERROR! Timeout` | Network connectivity issue in Ansible | Increase timeout: `-e ansible_timeout=30` |
| `Error: Error acquiring the state lock` | Concurrent Terraform operations | Wait or force unlock if necessary |

## Docker Performance Tuning

Optimizing Docker performance on Swarm nodes:

```bash
# Check Docker info
docker info

# Set logging driver to json-file with limits
cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

# Restart Docker daemon
systemctl restart docker

# Set resource limits on container level
docker service update --limit-cpu 0.5 --limit-memory 512M CP-Planta_backend
```

## Database Maintenance

PostgreSQL database management commands:

```bash
# Connect to database
docker exec -it $(docker ps -q -f name=postgres) psql -U postgres

# Create database backup
docker exec $(docker ps -q -f name=postgres) pg_dump -U postgres postgres > backup.sql

# Restore database from backup
cat backup.sql | docker exec -i $(docker ps -q -f name=postgres) psql -U postgres postgres

# Check database status
docker exec -it $(docker ps -q -f name=postgres) psql -U postgres -c "SELECT version();"
```

## Load Balancing

Commands for checking and managing Traefik load balancing:

```bash
# Check Traefik configuration
docker service logs CP-Planta_traefik

# View Traefik dashboard (if enabled)
# Access https://traefik.cpplanta.duckdns.org

# Check all routers and services
curl -s http://localhost:8080/api/http/routers | jq .
curl -s http://localhost:8080/api/http/services | jq .
```
