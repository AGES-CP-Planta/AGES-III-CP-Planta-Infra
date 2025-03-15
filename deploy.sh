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
    echo -e "  -u, --update      Run in update mode (use update-deployment.sh if infrastructure exists)"
    echo -e "  --no-interactive   Run in non-interactive mode"
    echo -e "  -h, --help        Show this help message"
    echo ""
    echo -e "Example: ./deploy.sh --provider aws --regions multi"
}

# Default values
PROVIDER="aws"
REGIONS="single"
SKIP_TERRAFORM=false
CHECK_UPDATE=true
INTERACTIVE=true 

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
        -u|--update)
            CHECK_UPDATE=true
            shift
            ;;
        --no-interactive)
            INTERACTIVE=false
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

# Check if this is an update to existing infrastructure
if [[ "$CHECK_UPDATE" == "true" ]]; then
    if [[ "$REGIONS" == "single" ]]; then
        INVENTORY_FILE="static_ip.ini"
    else
        INVENTORY_FILE="multi_region_inventory.ini"
    fi
    
    if [[ -f "$INVENTORY_FILE" ]]; then
        # Attempt to verify connectivity to existing infrastructure
        echo -e "${YELLOW}Detected existing inventory file. Checking if infrastructure exists...${NC}"
        
        if [[ "$REGIONS" == "multi" ]]; then
            MANAGER_GROUP="primary_region"
        else
            MANAGER_GROUP="instance1"
        fi
        
        # Try to ping the first host in inventory with timeout
        FIRST_HOST=$(grep -m1 ansible_ssh_user $INVENTORY_FILE | awk '{print $1}')
        if [[ -n "$FIRST_HOST" ]]; then
            ping -c 1 -W 3 $FIRST_HOST >/dev/null 2>&1
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Existing infrastructure detected.${NC}"
                echo -e "${YELLOW}Switching to update mode...${NC}"
                
                if [[ -f "update-deployment.sh" ]]; then
                    echo -e "${YELLOW}Running update-deployment.sh...${NC}"
                    chmod +x update-deployment.sh
                    ./update-deployment.sh --provider $PROVIDER --regions $REGIONS
                    exit $?
                else
                    echo -e "${RED}update-deployment.sh not found. Creating it...${NC}"
                    # Create update script
                    cat > update-deployment.sh << 'EOL'
#!/bin/bash
# Auto-generated update-deployment.sh
# Please see update-deployment.sh documentation for full features

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
PROVIDER="aws"
REGIONS="single"
SERVICE="all"

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
        -s|--service)
            SERVICE="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Set project vars
if [[ -f .env ]]; then
    echo -e "${YELLOW}Loading environment variables from .env file...${NC}"
    export $(grep -v '^#' .env | xargs)
fi

# Determine inventory file
if [[ "$REGIONS" == "multi" ]]; then
    INVENTORY_FILE="multi_region_inventory.ini"
else
    INVENTORY_FILE="static_ip.ini"
fi

echo -e "${YELLOW}Updating Docker Swarm services...${NC}"
cd Swarm

# Update existing stack
ansible-playbook -i ../$INVENTORY_FILE ./swarm_setup.yml 

cd ..
echo -e "${GREEN}Update completed successfully!${NC}"
exit 0
EOL
                    chmod +x update-deployment.sh
                    ./update-deployment.sh --provider $PROVIDER --regions $REGIONS
                    exit $?
                fi
            fi
        fi
    fi
fi

# Set project vars
if [[ -f .env ]]; then
    echo -e "${YELLOW}Loading environment variables from .env file...${NC}"
    export $(grep -v '^#' .env | xargs)

    # Export Terraform-specific variables
    if [[ "$PROVIDER" == "azure" ]]; then
        export TF_VAR_azure_subscription_id="$AZURE_SUBSCRIPTION_ID"
    fi
else
    echo -e "${YELLOW}Warning: .env file not found, using default environment settings${NC}"
fi

# Create directories if they don't exist
mkdir -p ssh_keys Swarm

# Check for existing resources
if [[ "$SKIP_TERRAFORM" == "false" ]]; then
    echo -e "${YELLOW}Checking for existing resources...${NC}"
    
    chmod +x ./check-existing-resources.sh
    
    # First check if resources exist
    ./check-existing-resources.sh --provider $PROVIDER --regions $REGIONS --action check
    
    if [ $? -eq 0 ]; then
        if [[ "$INTERACTIVE" == "true" ]]; then
            # Interactive mode - prompt user for choice
            echo -e "${YELLOW}Would you like to:${NC}"
            echo -e "  1) ${BLUE}Import${NC} existing resources into Terraform state"
            echo -e "  2) ${BLUE}Delete${NC} existing resources and create new ones"
            echo -e "  3) ${BLUE}Skip${NC} Terraform provisioning entirely"
            echo -e "  4) ${BLUE}Continue${NC} anyway (might fail if resources exist)"
            echo -e "  5) ${RED}Abort${NC} deployment"
            read -p "Enter your choice (1-5): " RESOURCE_ACTION
            
            case $RESOURCE_ACTION in
                1)
                    echo -e "${YELLOW}Importing existing resources...${NC}"
                    ./check-existing-resources.sh --provider $PROVIDER --regions $REGIONS --action import
                    ;;
                2)
                    echo -e "${YELLOW}Deleting existing resources...${NC}"
                    ./check-existing-resources.sh --provider $PROVIDER --regions $REGIONS --action delete
                    ;;
                3)
                    echo -e "${YELLOW}Skipping Terraform provisioning...${NC}"
                    SKIP_TERRAFORM=true
                    ;;
                4)
                    echo -e "${YELLOW}Continuing with Terraform apply...${NC}"
                    ;;
                5|*)
                    echo -e "${RED}Deployment aborted.${NC}"
                    exit 1
                    ;;
            esac
        else
            # Non-interactive mode - assume default action (import)
            echo -e "${YELLOW}Running in non-interactive mode. Importing existing resources...${NC}"
            ./check-existing-resources.sh --provider $PROVIDER --regions $REGIONS --action import
        fi
    fi
fi

# Provision infrastructure with Terraform if not skipped
if [[ "$SKIP_TERRAFORM" == "false" ]]; then
    echo -e "${BLUE}Selected provider: $PROVIDER, Regions: $REGIONS${NC}"
    echo -e "${YELLOW}Running Terraform for $PROVIDER...${NC}"

    if [[ "$PROVIDER" == "aws" ]]; then
        if [[ "$REGIONS" == "single" ]]; then
            cd TerraformAWS
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

    echo -e "${YELLOW}Waiting for instances to initialize (40 seconds)...${NC}"
    sleep 40

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
    ANSIBLE_CONFIG=./ansible.cfg ansible-playbook -i ../multi_region_inventory.ini ./swarm_multi_region_setup.yml 
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Multi-region setup playbook encountered errors.${NC}"
        echo -e "${YELLOW}Trying to continue anyway...${NC}"
    else
        echo -e "${GREEN}Multi-region deployment completed successfully!${NC}"
    fi
else
    echo -e "${YELLOW}Using single-region configuration...${NC}"
    ANSIBLE_CONFIG=./ansible.cfg ansible-playbook -i ../static_ip.ini ./swarm_setup.yml 
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Swarm setup playbook encountered errors.${NC}"
        echo -e "${YELLOW}Checking Docker Swarm status on manager node...${NC}"
        
        # Extract manager IP and key from inventory
        manager_ip=$(grep -A1 '\[instance1\]' ../static_ip.ini | tail -n1 | awk '{print $1}')
        manager_key=$(grep -A1 '\[instance1\]' ../static_ip.ini | tail -n1 | grep -o 'ansible_ssh_private_key_file=[^ ]*' | cut -d= -f2)
        
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

# Save current git commit as deployment marker
git rev-parse HEAD > ../.last_deployment 2>/dev/null || echo "unable to create deployment marker" > ../.last_deployment

cd ..
echo -e "${GREEN}Deployment process completed on $PROVIDER using $REGIONS region mode.${NC}"
echo -e "${YELLOW}You should now be able to access your services at the provided endpoints.${NC}"

# Display node IPs for user reference
if [[ "$PROVIDER" == "aws" ]]; then
    if [[ "$REGIONS" == "single" ]]; then
        echo -e "${BLUE}AWS Instance IPs:${NC}"
        jq -r '.resources[] | select(.type == "aws_instance") | .instances[] | .attributes.public_ip' TerraformAWS/terraform.tfstate
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