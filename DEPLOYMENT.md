# CP-Planta Deployment Instructions

This document provides detailed instructions for deploying and updating the CP-Planta infrastructure using both manual and automated approaches.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Local Deployment](#local-deployment)
- [Automated Deployment with GitHub Actions](#automated-deployment-with-github-actions)
- [Secrets Management](#secrets-management)
- [Continuous Updates](#continuous-updates)
- [Troubleshooting](#troubleshooting)

## Prerequisites

Before deploying, ensure you have the following:

1. **Cloud Provider Credentials**:
   - For AWS: `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
   - For Azure: `AZURE_SUBSCRIPTION_ID`, `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, and `AZURE_CLIENT_SECRET`

2. **Required Tools for Local Deployment**:
   - [Terraform](https://www.terraform.io/downloads.html) (v1.0.0+)
   - [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) (v2.9+)
   - [AWS CLI](https://aws.amazon.com/cli/) (for AWS deployments)
   - [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (for Azure deployments)
   - [OpenSSL](https://www.openssl.org/) (for secrets encryption)
   - [jq](https://stedolan.github.io/jq/download/) (for parsing JSON output)

3. **Configuration Files**:
   - `.env` file with your secrets and configuration values (see [Secrets Management](#secrets-management))

## Local Deployment

### Initial Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Saccilotto/AGES-III-CP-Planta-Infra.git
   cd AGES-III-CP-Planta-Infra
   ```

2. **Create and configure your secrets**:
   ```bash
   ./secrets-manager.sh template
   cp .env.example .env
   nano .env  # Fill in your credentials and configuration
   ./secrets-manager.sh check  # Verify all required secrets are present
   ```

3. **Make deployment scripts executable**:
   ```bash
   chmod +x deploy.sh update-deployment.sh secrets-manager.sh
   ```

### Running a Full Deployment

The `deploy.sh` script handles both fresh deployments and updates to existing infrastructure:

```bash
# For AWS single-region deployment (default)
./deploy.sh --provider aws --regions single

# For AWS multi-region deployment
./deploy.sh --provider aws --regions multi

# For Azure deployment
./deploy.sh --provider azure --regions single

# Skip Terraform provisioning (use existing infrastructure)
./deploy.sh --provider aws --regions single --skip-terraform
```

The deployment script will:
1. Create the necessary infrastructure using Terraform
2. Generate SSH keys for secure access
3. Configure the Docker Swarm cluster using Ansible
4. Deploy the application stack

### Updating Existing Infrastructure

For targeted updates to specific components, use the `update-deployment.sh` script:

```bash
# Update only frontend services
./update-deployment.sh --provider aws --regions single --service frontend

# Update only backend services
./update-deployment.sh --provider aws --regions single --service backend

# Update only database services
./update-deployment.sh --provider aws --regions single --service db

# Update infrastructure with Terraform
./update-deployment.sh --provider aws --regions single --infra

# Force update all services
./update-deployment.sh --provider aws --regions single --service all --force
```

## Automated Deployment with GitHub Actions

This project includes two GitHub Actions workflows:

1. **Full Infrastructure Deployment** (`full-deployment.yml`)
2. **Automatic Deployment Update** (`auto-update.yml`)

### Setting Up GitHub Actions

1. **Add Required Secrets to GitHub**:
   - Go to your GitHub repository
   - Navigate to Settings → Secrets and variables → Actions
   - Add the following secrets:
     - `AWS_ACCESS_KEY_ID`
     - `AWS_SECRET_ACCESS_KEY`
     - `AZURE_SUBSCRIPTION_ID`
     - `AZURE_TENANT_ID`
     - `AZURE_CLIENT_ID`
     - `AZURE_CLIENT_SECRET`
     - `DOMAIN_NAME`
     - `ACME_EMAIL`
     - `PGADMIN_EMAIL`
     - `PGADMIN_PASSWORD`
     - `DEPLOY_SSH_KEY` (a private SSH key with access to your instances)

2. **Create SSH Deploy Key**:
   ```bash
   ssh-keygen -t rsa -b 4096 -f deploy_key -N ""
   ```

   - Add the private key content to GitHub as `DEPLOY_SSH_KEY`
   - Make sure this key has access to your cloud instances

### Running GitHub Workflows

#### Full Deployment

1. Go to the "Actions" tab in your GitHub repository
2. Select "Full Infrastructure Deployment" from the workflows
3. Click "Run workflow"
4. Set the following parameters:
   - **Environment**: production, staging, or dev
   - **Cloud provider**: aws or azure
   - **Regions mode**: single or multi
   - **Skip Terraform**: true/false
5. Click "Run workflow" to start the deployment

#### Automatic Updates

The auto-update workflow runs automatically when:
- Code is pushed to the main branch
- A pull request is merged into the main branch

You can also trigger it manually with specific parameters:
1. Go to the "Actions" tab in your GitHub repository
2. Select "Automatic Deployment Update" from the workflows
3. Click "Run workflow" and set your parameters
4. Click "Run workflow" to start the update

## Secrets Management

The `secrets-manager.sh` script provides tools for managing sensitive credentials:

```bash
# Create a template .env file
./secrets-manager.sh template

# Check if all required secrets are present
./secrets-manager.sh check

# Encrypt your .env file
./secrets-manager.sh encrypt --password "your-secure-password"

# Decrypt your .env.encrypted file
./secrets-manager.sh decrypt --password "your-secure-password"
```

### Best Practices for Secrets

1. **Never commit unencrypted secrets** to version control
2. **Rotate credentials** periodically for better security
3. **Use different credentials** for different environments
4. **Encrypt your .env file** when not actively using it
5. **Consider using a dedicated secrets manager** for production:
   - AWS Secrets Manager
   - Azure Key Vault
   - HashiCorp Vault

## Continuous Updates

For a typical development workflow:

1. Make changes to the codebase
2. Commit and push to your branch
3. Create a pull request to main
4. After the PR is merged, the auto-update workflow will run automatically
5. The workflow detects what changed and updates only the necessary components

## Troubleshooting

### Common Issues

1. **SSH Connection Issues**:
   - Check that the security groups/NSGs allow SSH (port 22)
   - Verify the SSH keys have correct permissions (`chmod 400 ssh_keys/*.pem`)
   - Try connecting manually to verify access: `ssh -i ssh_keys/instance1.pem username@ip-address`

2. **Terraform Errors**:
   - Ensure your cloud provider credentials are correct in `.env`
   - Check the Terraform state with `terraform state list`
   - For state issues: `terraform refresh`

3. **Ansible Errors**:
   - Verify the inventory file is correctly generated (`cat static_ip.ini`)
   - Ensure the hosts are reachable: `ansible -i static_ip.ini all -m ping`
   - Add `-vvv` to ansible-playbook commands for verbose output

4. **Docker Swarm Issues**:
   - Check swarm status: `docker node ls`
   - Check service status: `docker service ls`
   - View service logs: `docker service logs [service_name]`

### Accessing Deployment Logs

1. **Local Deployments**:
   - Terraform logs are in the respective Terraform directory
   - Ansible logs are output to the console (redirect to a file if needed)

2. **GitHub Actions Deployments**:
   - View logs in the GitHub Actions tab
   - Download deployment outputs artifact for infrastructure details

### Getting Help

If you encounter persistent issues:
1. Check the project README and DEPLOYMENT.md (this file)
2. Review GitHub Issues for similar problems
3. Open a new issue with detailed information about your problem