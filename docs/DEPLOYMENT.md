# CP-Planta Deployment Guide

This document provides comprehensive instructions for deploying and managing the CP-Planta infrastructure across AWS and Azure cloud platforms.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Environment Setup](#environment-setup)
- [Deployment Options](#deployment-options)
- [Infrastructure Components](#infrastructure-components)
- [Service Architecture](#service-architecture)
- [DNS Configuration](#dns-configuration)
- [Maintenance Operations](#maintenance-operations)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Future Enhancements](#future-enhancements)

## Prerequisites

Before deploying, ensure you have the following:

### Required Tools

- [Terraform](https://www.terraform.io/downloads.html) (v1.0.0+)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) (v2.9+)
- [AWS CLI](https://aws.amazon.com/cli/) (for AWS deployments)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (for Azure deployments)
- [Docker](https://docs.docker.com/engine/install/) (for local testing)
- [Git](https://git-scm.com/downloads)
- [OpenSSL](https://www.openssl.org/)

### Cloud Provider Credentials

#### AWS

- AWS Access Key ID
- AWS Secret Access Key
- Appropriate IAM permissions for:
  - EC2
  - VPC
  - Security Groups
  - S3 (for Terraform state)

#### Azure

- Azure Subscription ID
- Azure Tenant ID
- Azure Client ID
- Azure Client Secret
- Appropriate RBAC permissions for:
  - Resource Groups
  - Virtual Networks
  - Virtual Machines
  - Storage Accounts

## Environment Setup

### Setting Up Environment Variables

1. Create a template environment file:

   ```bash
   ./secrets-manager.sh template
   ```

2. Copy the template and fill in your credentials:

   ```bash
   cp .env.example .env
   nano .env  # Edit with your credentials
   ```

3. Verify your environment configuration:

   ```bash
   ./secrets-manager.sh check
   ```

4. For team environments, encrypt your credentials:

   ```bash
   ./secrets-manager.sh encrypt -p "your-secure-password"
   ```

### Repository Structure

The repository is organized as follows:

```plaintext
.
├── .github/
│   └── workflows/
├── config/
├── deployment/
│   ├── ansible/
│   │   ├── playbooks/
│   │   │   ├── ansible.cfg
│   │   │   ├── swarm_setup.yml
│   │   └── roles/
│   │       ├── database/
│   │       │   ├── pgbouncer/
│   │       │   │   ├── dockerfile.pgbouncer
│   │       │   │   ├── pgbouncer.ini
│   │       │   │   └── userlist.txt
│   │       │   └── postgresql/
│   │       │       ├── dockerfile.postgres
│   │       │       ├── pg_hba.conf
│   │       │       ├── postgres-entrypoint.sh
│   │       │       ├── postgresql.conf
│   │       │       └── repmgr.conf
│   │       └── networking/
│   │           ├── dns/
│   │           │   └── Corefile
│   │           └── zones/
│   │               └── cpplanta.duckdns.org.db
│   ├── kubernetes/
│   │   └── manifests/
│   └── swarm/
│       ├── replication_setup.sh
│       └── stack.yml
├── docs/
│   ├── ENHANCEMENTS.md
│   └── single-region-diagram.svg
├── terraform/
│   ├── aws/
│   └── azure/
├── .env.example
├── CLI-REFERENCE.md
├── DEPLOYMENT.md
├── LICENSE
├── README.md
├── check-existing-resources.sh
├── deploy.sh
├── destroy.sh
├── save-terraform-state.sh
└── secrets-manager.sh
```

## Deployment Options

CP-Planta supports deployment to different cloud providers:

### Single-Region Deployment

A standard deployment with one manager node and one worker node in a single AWS region or Azure location.

```bash
# For AWS
./deploy.sh --provider aws

# For Azure
./deploy.sh --provider azure
```

This setup provides:

- Basic high availability through service replication
- Lower cost with minimal infrastructure
- Simpler networking configuration
- Faster deployment time

### Cloud Provider Selection

The infrastructure can be deployed to either AWS or Azure with the same code base:

```bash
# For AWS deployment
./deploy.sh --provider aws

# For Azure deployment
./deploy.sh --provider azure
```

### Update Deployment

For updating existing infrastructure:

```bash
# Update all services
./update-deployment.sh --provider aws

# Update specific service
./update-deployment.sh --provider aws --service backend
```

### Destroy Infrastructure

When you no longer need the infrastructure:

```bash
./destroy.sh --provider aws
```

## Infrastructure Components

### AWS Infrastructure

- VPC with public subnet
- 2 EC2 instances (t2.small)
- Security group with required ports
- Elastic IPs for stable addressing
- SSH key pairs for secure access

### Azure Infrastructure

- Resource Group
- Virtual Network with subnet
- 2 Virtual Machines (Standard_B2s)
- Network Security Group
- Public IPs for external access

## Service Architecture

The Docker Swarm stack consists of the following services:

### Core Services

- **Traefik**: Edge router and reverse proxy
  - Handles SSL termination (Let's Encrypt)
  - Routes traffic to appropriate services
  - Provides dashboard for request visualization

- **PostgreSQL**: Database layer
  - Primary node for write operations
  - Connected to application services

### Application Services

- **Backend API**: Main application backend
  - Node.js-based API services
  - Connected to PostgreSQL database
  - Exposed via Traefik on api.cpplanta.duckdns.org

- **Frontend**: User interface
  - React-based web application
  - Communicates with Backend API
  - Exposed via Traefik on cpplanta.duckdns.org

### Support Services

- **PgAdmin**: Database administration
  - Web UI for PostgreSQL management
  - Exposed via Traefik on pgadmin.cpplanta.duckdns.org

- **CoreDNS**: Internal DNS resolution
  - Service discovery within the cluster
  - Custom DNS zones for internal routing

- **Visualizer**: Swarm visualization
  - Visual representation of container placement
  - Shows node distribution and health
  - Exposed via Traefik on viz.cpplanta.duckdns.org

## DNS Configuration

### External DNS with DuckDNS

The project uses DuckDNS for DNS resolution:

1. Create a DuckDNS account at [DuckDNS](https://www.duckdns.org/)

2. Register the following subdomains:
   - `cpplanta.duckdns.org` (main application)
   - `api.cpplanta.duckdns.org` (API endpoints)
   - `pgadmin.cpplanta.duckdns.org` (Database admin)
   - `viz.cpplanta.duckdns.org` (Visualizer dashboard)

3. Set up automatic DNS updates via deploy post-steps while duckdns env is sourced.

4. The post deploy phase on the deploy script will install a cron job to keep your DNS records updated if your server's IP changes.

### Internal DNS with CoreDNS

For internal service discovery, the stack includes CoreDNS:

- Configured via `Swarm/Corefile` and zone files
- Provides DNS resolution between services
- Automatically deployed as part of the stack

## Maintenance Operations

### Updating Services

To update specific services without full redeployment:

```bash
# Update all services
./update-deployment.sh --provider aws

# Update only backend
./update-deployment.sh --provider aws --service backend

# Update only frontend
./update-deployment.sh --provider aws --service frontend

# Update only database services
./update-deployment.sh --provider aws --service db
```

### Scaling Services

To scale specific services:

```bash
# Connect to manager node
ssh -i ssh_keys/instance1.pem ubuntu@<manager-ip>

# Scale a service
docker service scale CP-Planta_backend=3
```

### Database Backups

To backup the PostgreSQL database:

```bash
# On manager node
docker exec $(docker ps -q -f name=postgres) pg_dump -U postgres postgres > backup.sql
```

### Adding Nodes to Swarm

For manual node expansion:

```bash
# Get worker join token from manager
docker swarm join-token worker

# On new worker node
docker swarm join --token <token> <manager-ip>:2377
```

## Monitoring

### Service Status

Check the status of your deployed services:

```bash
ansible -i static_ip.ini instance1 -m shell -a "docker service ls"
```

### Resource Visualization

Access the Visualizer dashboard at `https://viz.cpplanta.duckdns.org` to see a graphic representation of your Swarm cluster with service distribution.

### Container Monitoring

The deployment includes monitoring tools on all nodes:

- **ctop**: For container resource usage monitoring
- **htop**: For system resource monitoring

```bash
# Connect to a node
ssh -i ssh_keys/instance1.pem ubuntu@<instance-ip>

# Monitor containers
sudo ctop

# Monitor system resources
htop
```

### Log Management

View service logs:

```bash
# Connect to manager node
ssh -i ssh_keys/instance1.pem ubuntu@<manager-ip>

# View service logs
docker service logs CP-Planta_backend
```

## Troubleshooting

### Connection Issues

If you can't connect to your instances:

```bash
# Check SSH key permissions
chmod 400 ssh_keys/*.pem

# Verify security group/NSG rules
# For AWS:
aws ec2 describe-security-groups --group-id <security-group-id>

# For Azure:
az network nsg show --name cp-planta-nsg --resource-group cp-planta-ages
```

### Service Failures

If services fail to start:

```bash
# Check service logs
docker service logs CP-Planta_frontend
docker service logs CP-Planta_backend

# Inspect service configuration
docker service inspect CP-Planta_backend
```

### DNS Resolution Problems

If DNS resolution fails:

```bash
# Verify DuckDNS records
curl https://www.duckdns.org/update?domains=cpplanta&token=<your-token>&txt=verify

# Check internal DNS
docker exec $(docker ps -q -f name=dns) dig @localhost cpplanta.duckdns.org
```

### Common Error Scenarios

| Issue | Possible Cause | Solution |
|-------|---------------|----------|
| Services not starting | Resource constraints | Increase VM size or reduce service constraints |
| Database connection errors | Wrong connection string | Check connection string and connection pool settings |
| SSL certificate errors | Let's Encrypt rate limiting | Wait and retry, or use staging environment for testing |
| Node communication issues | Security group rules | Ensure ports 2377, 7946, and 4789 are open between nodes |

## Future Enhancements

The CP-Planta infrastructure project has several planned future enhancements:

### Kubernetes Migration Path

A future version will support Kubernetes as an orchestration platform alongside Docker Swarm:

- Helm charts for all services
- Support for managed Kubernetes services (EKS, AKS)
- Kubernetes-specific monitoring with Prometheus and Grafana
- Horizontal Pod Autoscaling for dynamic workloads

### Multi-Cloud Orchestration

Enhanced support for multi-cloud deployments:

- Simultaneous deployment across AWS and Azure
- Cross-cloud service discovery
- Load balancing between clouds
- Unified monitoring across providers

### Infrastructure Expansion

Additional infrastructure capabilities:

- GCP support as a third cloud provider
- Terraform modules for component reusability
- Auto-scaling node groups
- Spot/Low-priority instance support for cost optimization
- Blue/Green deployment option for zero-downtime updates

### Enhanced Security Features

Improved security posture:

- Vault integration for secrets management
- Private subnets with bastion hosts
- VPN connectivity options
- Enhanced IAM/RBAC configurations
- Security scanning integration (Trivy, Clair)
- Compliance reporting

### Advanced Monitoring and Alerting

More comprehensive monitoring:

- Prometheus + Grafana dashboards
- Distributed tracing with Jaeger
- Log aggregation with ELK stack
- Automatic alerts via email, Slack, etc.
- Performance benchmarking tools

### CI/CD Pipeline Enhancements

Improved deployment pipeline:

- Integration testing in CI
- Canary deployments
- Chaos engineering testing
- Automatic rollbacks on failure
- Environment promotion workflows

These enhancements will be prioritized based on project requirements and community feedback. Contributions to any of these areas are welcome!
