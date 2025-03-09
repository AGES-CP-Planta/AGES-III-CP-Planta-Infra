# AGES-III-CP-Planta-Infra

This repository contains Infrastructure as Code (IaC) for deploying and configuring(CaC) the CP-Planta application on either AWS or Azure cloud providers using Terraform and Ansible.

## Project Structure

```plaintext
CP-Planta-Infra/
├── ssh_keys/               # Generated SSH keys (gitignored)
├── Swarm/
│   ├── ansible.cfg         # Ansible configuration for Swarm setup
│   ├── stack.yml           # Docker Swarm stack definition
│   └── swarm_setup.yml     # Ansible playbook for Swarm setup
├── TerraformAWS/
│   ├── instance.tf         # AWS EC2 instance configuration
│   ├── inventory.tf        # Generates Ansible inventory for AWS
│   ├── main.tf             # Main AWS Terraform configuration
│   ├── network.tf          # AWS VPC and network configuration
│   ├── outputs.tf          # Terraform outputs for AWS
│   ├── providers.tf        # AWS provider configuration
│   └── variables.tf        # Variables for AWS deployment
├── TerraformAzure/
│   ├── inventory.tf        # Generates Ansible inventory for Azure
│   ├── main.tf             # Main Azure Terraform configuration
│   ├── network.tf          # Azure VNET and network configuration
│   ├── outputs.tf          # Terraform outputs for Azure
│   ├── providers.tf        # Azure provider configuration
│   ├── resource_group.tf   # Azure resource group configuration
│   ├── variables.tf        # Variables for Azure deployment
│   └── vm.tf               # Azure VM configuration
├── .env                    # Environment variables (gitignored)
├── .env.example            # Example environment variables
├── .gitignore              # Git ignore file
├── deploy.sh               # Main deployment script
├── README.md               # This file
└── static_ip.ini           # Generated Ansible inventory (gitignored)
```

## Prerequisites

1. [Terraform](https://www.terraform.io/downloads.html) (v1.0.0+)
2. [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) (v2.9+)
3. [AWS CLI](https://aws.amazon.com/cli/) (for AWS deployments)
4. [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (for Azure deployments)
5. [Docker](https://docs.docker.com/engine/install/) (for local testing)

## Setup

1. Clone this repository:

   ```plaintext
   git clone https://github.com/Saccilotto/CP-Planta-Infra.git
   cd CP-Planta-Infra
   ```

2. Create `.env` file from the example:

   ```plaintext
   cp .env.example .env
   ```

3. Edit the `.env` file with your cloud provider credentials and other configuration.

4. Make the deployment script executable:

   ```plaintext
   chmod +x deploy.sh
   ```

5. Create necessary directories:

   ```plaintext
   mkdir -p ssh_keys
   ```

## Usage

### Deploying to AWS or Azure

Use the deploy script with the `--provider` flag to choose the cloud provider:

```bash
# Deploy to AWS (default)
./deploy.sh --provider aws

# Deploy to Azure
./deploy.sh --provider azure

# Show help
./deploy.sh --help
```

The deployment process:

1. Runs Terraform to provision the infrastructure
2. Generates SSH keys and Ansible inventory
3. Runs Ansible to configure Docker Swarm
4. Deploys the application stack

### Customizing the Deployment

To customize the deployment:

1. Edit the Terraform variables in `TerraformAWS/variables.tf` or `TerraformAzure/variables.tf`
2. Modify the Docker Swarm configuration in `Swarm/swarm_setup.yml`
3. Update the Docker stack definition in `Swarm/stack.yml`

## Infrastructure Components

### AWS Infrastructure

- VPC with public subnets
- EC2 instances with Elastic IPs
- Security Groups for required ports
- SSH keys for secure access

### Azure Infrastructure

- Resource Group
- Virtual Network with subnets
- Virtual Machines with public IPs
- Network Security Groups
- SSH keys for secure access

### Common Configuration

- Docker Swarm cluster setup
- Docker stack deployment
- PostgreSQL database setup with primary and replica
- PgAdmin and PgBouncer for database management
- Frontend and Backend services

## Troubleshooting

### Common Issues

1. **SSH Connection Issues**:
   - Check that the security groups/NSGs allow SSH (port 22)
   - Verify the SSH keys have correct permissions (`chmod 400 ssh_keys/*.pem`)

2. **Terraform Errors**:
   - Ensure your cloud provider credentials are correct in `.env`
   - Check the Terraform state with `terraform state list`

3. **Ansible Errors**:
   - Verify the inventory file is correctly generated (`cat static_ip.ini`)
   - Ensure the hosts are reachable (`ansible -i static_ip.ini all -m ping`)

### Logs

- Terraform logs: Set `TF_LOG=DEBUG` before running Terraform
- Ansible logs: Add `-v` to ansible-playbook commands for verbose output

## Development

### Adding New Services

1. Edit `Swarm/stack.yml` to add new services
2. Update `Swarm/swarm_setup.yml` to include service configuration
3. Run the deployment script to update the stack

### Extending to Other Cloud Providers

1. Create a new directory (e.g., `TerraformGCP/`)
2. Create Terraform configuration for the new provider
3. Update `deploy.sh` to support the new provider

## License

[MIT License](LICENSE)

## Contributors

- André Sacilotto Santos
