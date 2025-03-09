#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Help function
function show_help {
    echo -e "${BLUE}Usage: ./deploy.sh [OPTIONS]${NC}"
    echo -e "Deploy infrastructure on AWS or Azure and configure Docker Swarm"
    echo ""
    echo -e "Options:"
    echo -e "  -p, --provider    Specify cloud provider (aws or azure), default: aws"
    echo -e "  -r, --regions     Specify region mode (single or multi), default: single"
    echo -e "  -s, --skip-terraform Skip the Terraform provisioning step (use existing infrastructure)"
    echo -e "  -h, --help        Show this help message"
    echo ""
    echo -e "Example: ./deploy.sh --provider aws --regions multi"
}

# Default values
PROVIDER="aws"
REGIONS="single"
SKIP_TERRAFORM=false

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
        -s|--skip-terraform)
            SKIP_TERRAFORM=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Set project vars
if [[ -f .env ]]; then
    echo -e "${YELLOW}Loading environment variables from .env file...${NC}"
    export $(grep -v '^#' .env | xargs)
else
    echo -e "${YELLOW}Warning: .env file not found, using default environment settings${NC}"
fi

# Create directories if they don't exist
mkdir -p ssh_keys Swarm

# Provision infrastructure with Terraform if not skipped
if [[ "$SKIP_TERRAFORM" == "false" ]]; then
    echo -e "${BLUE}Selected provider: $PROVIDER, Regions: $REGIONS${NC}"
    echo -e "${YELLOW}Running Terraform for $PROVIDER...${NC}"

    if [[ "$PROVIDER" == "aws" ]]; then
        if [[ "$REGIONS" == "single" ]]; then
            cd SimpleTerraformAWS
        else
            cd TerraformAWS
        fi
        terraform init
        
        # Check if terraform plan works before applying
        echo -e "${YELLOW}Checking Terraform plan...${NC}"
        terraform plan -out=tf.plan
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}Terraform plan failed. Please check your configuration and AWS credentials.${NC}"
            exit 1
        fi
        
        echo -e "${YELLOW}Applying Terraform plan...${NC}"
        terraform apply tf.plan
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}Terraform apply failed.${NC}"
            exit 1
        fi
    elif [[ "$PROVIDER" == "azure" ]]; then
        cd TerraformAzure
        terraform init
        
        # Check if terraform plan works before applying
        echo -e "${YELLOW}Checking Terraform plan...${NC}"
        terraform plan -out=tf.plan
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}Terraform plan failed. Please check your configuration and Azure credentials.${NC}"
            exit 1
        fi
        
        echo -e "${YELLOW}Applying Terraform plan...${NC}"
        terraform apply -auto-approve tf.plan
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}Terraform apply failed.${NC}"
            exit 1
        fi
    fi

    # Return to project root
    cd ..
else
    echo -e "${YELLOW}Skipping Terraform provisioning as requested.${NC}"
fi

# Set correct permissions for SSH keys
echo -e "${YELLOW}Setting proper permissions for SSH keys...${NC}"
chmod 400 ssh_keys/*.pem

# Deploy the stack on Docker Swarm
echo -e "${YELLOW}Deploying Docker Swarm stack...${NC}"
cd Swarm

if [[ "$REGIONS" == "multi" ]]; then
    echo -e "${YELLOW}Using multi-region configuration...${NC}"
    ANSIBLE_CONFIG=./ansible.cfg ansible-playbook -i ../multi_region_inventory.ini ./swarm_multi_region_setup.yml --ask-become-pass
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Multi-region setup playbook encountered errors.${NC}"
        echo -e "${YELLOW}Trying to continue anyway...${NC}"
    else
        echo -e "${GREEN}Multi-region deployment completed successfully!${NC}"
    fi
else
    echo -e "${YELLOW}Using single-region configuration...${NC}"
    ANSIBLE_CONFIG=./ansible.cfg ansible-playbook -i ../static_ip.ini ./swarm_setup.yml --ask-become-pass
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Swarm setup playbook encountered errors.${NC}"
        echo -e "${YELLOW}Checking Docker Swarm status on manager node...${NC}"
        
        # Extract manager IP and key from inventory
        manager_ip=$(grep -A1 '\[CPPlanta1\]' ../static_ip.ini | tail -n1 | awk '{print $1}')
        manager_key=$(grep -A1 '\[CPPlanta1\]' ../static_ip.ini | tail -n1 | grep -o 'ansible_ssh_private_key_file=[^ ]*' | cut -d= -f2)
        
        # Check if Docker Swarm is running on manager
        ssh -i $manager_key ubuntu@$manager_ip "docker node ls" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Docker Swarm appears to be running despite errors. You may need to check specific services.${NC}"
        else
            echo -e "${RED}Docker Swarm does not appear to be running. Please check logs and resolve issues.${NC}"
        fi
    else
        echo -e "${GREEN}Single-region deployment completed successfully!${NC}"
    fi
fi

cd ..
echo -e "${GREEN}Deployment process completed on $PROVIDER using $REGIONS region mode.${NC}"
echo -e "${YELLOW}You should now be able to access your services at the provided endpoints.${NC}"

# Display node IPs for user reference
if [[ "$PROVIDER" == "aws" ]]; then
    if [[ "$REGIONS" == "single" ]]; then
        echo -e "${BLUE}AWS Instance IPs:${NC}"
        jq -r '.resources[] | select(.type == "aws_instance") | .instances[] | .attributes.public_ip' SimpleTerraformAWS/terraform.tfstate
    else
        echo -e "${BLUE}AWS Multi-Region Instance IPs:${NC}"
        echo -e "${YELLOW}Primary Region:${NC}"
        jq -r '.resources[] | select(.type == "aws_instance" and .name == "primary_region_instances") | .instances[] | .attributes.public_ip' TerraformAWS/terraform.tfstate
        echo -e "${YELLOW}Secondary Region:${NC}"
        jq -r '.resources[] | select(.type == "aws_instance" and .name == "secondary_region_instances") | .instances[] | .attributes.public_ip' TerraformAWS/terraform.tfstate
    fi
elif [[ "$PROVIDER" == "azure" ]]; then
    echo -e "${BLUE}Azure VM IPs:${NC}"
    jq -r '.resources[] | select(.type == "azurerm_virtual_machine") | .instances[] | .attributes.public_ip_address' TerraformAzure/terraform.tfstate
fi

exit 0