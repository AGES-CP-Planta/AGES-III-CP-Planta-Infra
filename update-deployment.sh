#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Help function
function show_help {
    echo -e "${BLUE}Usage: ./update-deployment.sh [OPTIONS]${NC}"
    echo -e "Update existing Docker Swarm services with latest images and configurations"
    echo ""
    echo -e "Options:"
    echo -e "  -p, --provider    Specify cloud provider (aws or azure), default: aws"
    echo -e "  -s, --service     Specify service to update (all, frontend, backend, db), default: all"
    echo -e "  -f, --force       Force update even if no changes detected"
    echo -e "  -i, --infra       Update infrastructure (Terraform apply)"
    echo -e "  -h, --help        Show this help message"
    echo ""
    echo -e "Example: ./update-deployment.sh --provider aws --service backend"
}

# Default values
PROVIDER="aws"
SERVICE="all"
FORCE_UPDATE=false
UPDATE_INFRA=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--provider)
            PROVIDER="$2"
            shift 2
            ;;
        -s|--service)
            SERVICE="$2"
            shift 2
            ;;
        -f|--force)
            FORCE_UPDATE=true
            shift
            ;;
        -i|--infra)
            UPDATE_INFRA=true
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
    echo -e "${RED}Error: .env file not found. Create it before running this script.${NC}"
    exit 1
fi

# Detect Git changes to determine what needs updating
if [[ "$FORCE_UPDATE" == "false" ]]; then
    echo -e "${YELLOW}Detecting changes since last deployment...${NC}"
    
    # Initialize or update last deployment marker
    if [[ ! -f .last_deployment ]]; then
        git rev-parse HEAD > .last_deployment
        echo -e "${YELLOW}No previous deployment marker found. Will perform full update.${NC}"
        FORCE_UPDATE=true
    else
        LAST_DEPLOY=$(cat .last_deployment)
        
        # Check for infrastructure changes
        INFRA_CHANGES=$(git diff --name-only $LAST_DEPLOY HEAD -- "Terraform*")
        if [[ -n "$INFRA_CHANGES" && "$UPDATE_INFRA" == "false" ]]; then
            echo -e "${YELLOW}Infrastructure changes detected:${NC}"
            echo "$INFRA_CHANGES"
            echo -e "${YELLOW}Consider running with --infra flag to apply these changes.${NC}"
        elif [[ -n "$INFRA_CHANGES" && "$UPDATE_INFRA" == "true" ]]; then
            echo -e "${YELLOW}Will apply infrastructure changes.${NC}"
        fi
        
        # Check for service-specific changes
        if [[ "$SERVICE" == "all" || "$SERVICE" == "frontend" ]]; then
            FRONTEND_CHANGES=$(git diff --name-only $LAST_DEPLOY HEAD -- "*frontend*")
            if [[ -n "$FRONTEND_CHANGES" ]]; then
                echo -e "${YELLOW}Frontend changes detected. Will update frontend services.${NC}"
                UPDATE_FRONTEND=true
            fi
        fi
        
        if [[ "$SERVICE" == "all" || "$SERVICE" == "backend" ]]; then
            BACKEND_CHANGES=$(git diff --name-only $LAST_DEPLOY HEAD -- "*backend*")
            if [[ -n "$BACKEND_CHANGES" ]]; then
                echo -e "${YELLOW}Backend changes detected. Will update backend services.${NC}"
                UPDATE_BACKEND=true
            fi
        fi
        
        if [[ "$SERVICE" == "all" || "$SERVICE" == "db" ]]; then
            DB_CHANGES=$(git diff --name-only $LAST_DEPLOY HEAD -- "*postgres*" "*pgadmin*")
            if [[ -n "$DB_CHANGES" ]]; then
                echo -e "${YELLOW}Database changes detected. Will update database services.${NC}"
                UPDATE_DB=true
            fi
        fi
        
        # Check for general Swarm configuration changes
        SWARM_CHANGES=$(git diff --name-only $LAST_DEPLOY HEAD -- "Swarm/*.yml" "Swarm/*.yaml" "Swarm/templates")
        if [[ -n "$SWARM_CHANGES" ]]; then
            echo -e "${YELLOW}Swarm configuration changes detected. Will update all services.${NC}"
            UPDATE_FRONTEND=true
            UPDATE_BACKEND=true
            UPDATE_DB=true
        fi
    fi
else
    echo -e "${YELLOW}Force update enabled. Will update all requested services.${NC}"
    if [[ "$SERVICE" == "all" || "$SERVICE" == "frontend" ]]; then
        UPDATE_FRONTEND=true
    fi
    
    if [[ "$SERVICE" == "all" || "$SERVICE" == "backend" ]]; then
        UPDATE_BACKEND=true
    fi
    
    if [[ "$SERVICE" == "all" || "$SERVICE" == "db" ]]; then
        UPDATE_DB=true
    fi
fi

# Update infrastructure if requested
if [[ "$UPDATE_INFRA" == "true" ]]; then
    echo -e "${YELLOW}Updating infrastructure with Terraform...${NC}"
    
    if [[ "$PROVIDER" == "aws" ]]; then
        cd TerraformAWS
    elif [[ "$PROVIDER" == "azure" ]]; then
        cd TerraformAzure
    fi
    
    terraform init
    terraform plan -out=tf.plan
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Terraform plan failed. Please check your configuration.${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Applying Terraform plan...${NC}"
    terraform apply tf.plan
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Terraform apply failed.${NC}"
        exit 1
    fi
    
    cd ..
fi

# Determine inventory file
INVENTORY_FILE="static_ip.ini"

# Check if inventory file exists
if [[ ! -f "$INVENTORY_FILE" ]]; then
    echo -e "${RED}Error: Inventory file $INVENTORY_FILE not found.${NC}"
    echo -e "${YELLOW}Have you run ./deploy.sh first?${NC}"
    exit 1
fi

# Update Swarm services
cd deployment/ansible

# Determine the manager node
MANAGER_GROUP="instance1"

# Use Ansible to get the manager node IP
MANAGER_IP=$(ansible -i ../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "hostname -I | awk '{print \$1}'" | grep -v "CHANGED" | tr -d '[:space:]')

if [[ -z "$MANAGER_IP" ]]; then
    echo -e "${RED}Error: Could not determine manager node IP.${NC}"
    exit 1
fi

echo -e "${YELLOW}Manager node IP: $MANAGER_IP${NC}"

# Copy updated stack files if needed
echo -e "${YELLOW}Copying updated stack file to manager node...${NC}"
ansible -i ../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m copy -a "src=./playbooks/stack.yml dest=/home/{{ ansible_ssh_user }}/stack.yml" --become

# Update DNS configuration files if needed
echo -e "${YELLOW}Updating DNS configuration...${NC}"
ansible -i ../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m file -a "path=/home/{{ ansible_ssh_user }}/dns/zones state=directory mode=0755" --become
ansible -i ../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m copy -a "src=../roles/networking/Corefile dest=/home/{{ ansible_ssh_user }}/dns/Corefile" --become
ansible -i ../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m copy -a "src=../roles/networking/zones/cpplanta.duckdns.org.db dest=/home/{{ ansible_ssh_user }}/dns/zones/cpplanta.duckdns.org.db" --become

# Update DNS zone file with manager IP
ansible -i ../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m replace -a "path=/home/{{ ansible_ssh_user }}/dns/zones/cpplanta.duckdns.org.db regexp='10\\.0\\.1\\.10' replace='{{ ansible_default_ipv4.address }}'" --become

# Redeploy the stack
echo -e "${YELLOW}Redeploying stack on manager node...${NC}"
ansible -i ../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "cd /home/{{ ansible_ssh_user }} && docker stack deploy --with-registry-auth --resolve-image always -c stack.yml CP-Planta" --become

# Update specific services if needed
STACK_PREFIX="CP-Planta"

if [[ "$UPDATE_FRONTEND" == "true" ]]; then
    echo -e "${YELLOW}Updating frontend services...${NC}"
    ansible -i ../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "docker service update --force ${STACK_PREFIX}_frontend" --become
fi

if [[ "$UPDATE_BACKEND" == "true" ]]; then
    echo -e "${YELLOW}Updating backend services...${NC}"
    ansible -i ../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "docker service update --force ${STACK_PREFIX}_backend" --become
fi

if [[ "$UPDATE_DB" == "true" ]]; then
    echo -e "${YELLOW}Updating database services...${NC}"
    ansible -i ../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "docker service update --force ${STACK_PREFIX}_postgres ${STACK_PREFIX}_pgadmin" --become
fi

# Update DNS service if needed
echo -e "${YELLOW}Updating DNS service...${NC}"
ansible -i ../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "docker service update --force ${STACK_PREFIX}_dns" --become

# Wait for services to stabilize
echo -e "${YELLOW}Waiting for services to stabilize...${NC}"
sleep 15

# Show service status
echo -e "${YELLOW}Service status:${NC}"
ansible -i ../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "docker service ls" --become

# Update deployment marker
git rev-parse HEAD > ../.last_deployment
echo -e "${GREEN}Updated deployment marker to current commit.${NC}"

cd ..
echo -e "${GREEN}Update process completed on $PROVIDER.${NC}"