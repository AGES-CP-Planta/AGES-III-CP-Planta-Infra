#!/bin/bash

# Help function
function show_help {
    echo "Usage: ./deploy.sh [OPTIONS]"
    echo "Deploy infrastructure on AWS or Azure and configure Docker Swarm"
    echo ""
    echo "Options:"
    echo "  -p, --provider    Specify cloud provider (aws or azure), default: aws"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Example: ./deploy.sh --provider azure"
}

# Default values
PROVIDER="aws"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--provider)
            PROVIDER="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate provider
if [[ "$PROVIDER" != "aws" && "$PROVIDER" != "azure" ]]; then
    echo "Error: Provider must be 'aws' or 'azure'"
    show_help
    exit 1
fi

# Set project vars
if [[ -f .env ]]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Warning: .env file not found, using default environment settings"
fi

# Create directories if they don't exist
mkdir -p ssh_keys Swarm

# Run Terraform based on selected provider
echo "Selected provider: $PROVIDER"
echo "Running Terraform for $PROVIDER..."

if [[ "$PROVIDER" == "aws" ]]; then
    cd TerraformAWS
    terraform init
    terraform apply -auto-approve
elif [[ "$PROVIDER" == "azure" ]]; then
    cd TerraformAzure
    terraform init
    terraform apply -auto-approve
fi

# Return to project root
cd ..

# Set correct permissions for SSH keys
chmod 400 ssh_keys/*.pem

# Deploy the stack on Docker Swarm
echo "Deploying Docker Swarm stack..."
cd Swarm
ANSIBLE_CONFIG=./ansible.cfg ansible-playbook -i ../static_ip.ini ./swarm_setup.yml || echo "Warning: swarm_setup playbook encountered errors."

# Optional: Run additional configuration
# Uncomment if needed
# cd ../Configuration/
# echo "Running Ansible configuration playbook..."
# ANSIBLE_CONFIG=./ansible.cfg ansible-playbook -i ../static_ip.ini ./runners.yml || echo "Warning: runners playbook encountered errors."

cd ..
echo "Deployment complete on $PROVIDER."