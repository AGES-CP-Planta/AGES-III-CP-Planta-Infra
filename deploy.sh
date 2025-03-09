#!/bin/bash

# Help function
function show_help {
    echo "Usage: ./deploy.sh [OPTIONS]"
    echo "Deploy infrastructure on AWS or Azure and configure Docker Swarm"
    echo ""
    echo "Options:"
    echo "  -p, --provider    Specify cloud provider (aws or azure), default: aws"
    echo "  -r, --regions     Specify region mode (single or multi), default: single"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Example: ./deploy.sh --provider aws --regions multi"
}

# Default values
PROVIDER="aws"
REGIONS="single"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--provider)
            PROVIDER="$2"
            shift 2
            ;;
        -r|--regions)
            REGIONS="$2"
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

# Set project vars
if [[ -f .env ]]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Warning: .env file not found, using default environment settings"
fi

# Create directories if they don't exist
mkdir -p ssh_keys Swarm

# Run Terraform based on selected provider
echo "Selected provider: $PROVIDER, Regions: $REGIONS"
echo "Running Terraform for $PROVIDER..."

if [[ "$PROVIDER" == "aws" ]]; then
    if [[ "$REGIONS" == "single" ]]; then
        cd SimpleTerraformAWS
    else
        cd TerraformAWS
    fi
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

if [[ "$REGIONS" == "multi" ]]; then
    echo "Using multi-region configuration..."
    ANSIBLE_CONFIG=./ansible.cfg ansible-playbook -i ../multi_region_inventory.ini ./swarm_multi_region_setup.yml || echo "Warning: multi-region setup playbook encountered errors."
else
    echo "Using single-region configuration..."
    ANSIBLE_CONFIG=./ansible.cfg ansible-playbook -i ../static_ip.ini ./swarm_setup.yml || echo "Warning: swarm_setup playbook encountered errors."
fi

cd ..
echo "Deployment complete on $PROVIDER using $REGIONS region mode."