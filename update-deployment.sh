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
    echo -e "  -r, --regions     Specify region mode (single or multi), default: single"
    echo -e "  -s, --service     Specify service to update (all, frontend, backend, db), default: all"
    echo -e "  -f, --force       Force update even if no changes detected"
    echo -e "  -i, --infra       Update infrastructure (Terraform apply)"
    echo -e "  -h, --help        Show this help message"
    echo ""
    echo -e "Example: ./update-deployment.sh --provider aws --regions multi --service backend"
}

# Default values
PROVIDER="aws"
REGIONS="single"
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
        -r|--regions)
            REGIONS="$2"
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
            DB_CHANGES=$(git diff --name-only $LAST_DEPLOY HEAD -- "*postgres*" "*pgadmin*" "*pgbouncer*")
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
        if [[ "$REGIONS" == "single" ]]; then
            cd SimpleTerraformAWS
        else
            cd TerraformAWS
        fi
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
if [[ "$REGIONS" == "multi" ]]; then
    INVENTORY_FILE="multi_region_inventory.ini"
else
    INVENTORY_FILE="static_ip.ini"
fi

# Check if inventory file exists
if [[ ! -f "$INVENTORY_FILE" ]]; then
    echo -e "${RED}Error: Inventory file $INVENTORY_FILE not found.${NC}"
    echo -e "${YELLOW}Have you run ./deploy.sh first?${NC}"
    exit 1
fi

# Update Swarm services
cd Swarm

# Determine the manager node based on regions mode
if [[ "$REGIONS" == "multi" ]]; then
    MANAGER_GROUP="primary_region"
else
    MANAGER_GROUP="instance1"
fi

# Use Ansible to get the manager node IP
MANAGER_IP=$(ansible -i ../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "hostname -I | awk '{print \$1}'" | grep -v "CHANGED" | tr -d '[:space:]')

if [[ -z "$MANAGER_IP" ]]; then
    echo -e "${RED}Error: Could not determine manager node IP.${NC}"
    exit 1
fi

echo -e "${YELLOW}Manager node IP: $MANAGER_IP${NC}"

# Copy updated stack files if needed
if [[ "$REGIONS" == "multi" ]]; then
    echo -e "${YELLOW}Copying updated stack files to primary and secondary regions...${NC}"
    ansible -i ../$INVENTORY_FILE primary_region --limit 1 -m template -a "src=./templates/stack_primary.yml.j2 dest=/home/{{ ansible_ssh_user }}/stack.yml" --become
    ansible -i ../$INVENTORY_FILE secondary_region --limit 1 -m template -a "src=./templates/stack_secondary.yml.j2 dest=/home/{{ ansible_ssh_user }}/stack.yml" --become
else
    echo -e "${YELLOW}Copying updated stack file to manager node...${NC}"
    ansible -i ../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m copy -a "src=./stack.yml dest=/home/{{ ansible_ssh_user }}/stack.yml" --become
fi

# Update DNS configuration files if needed
echo -e "${YELLOW}Updating DNS configuration...${NC}"
ansible -i ../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m file -a "path=/home/{{ ansible_ssh_user }}/dns/zones state=directory mode=0755" --become
ansible -i ../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m copy -a "src=./Corefile dest=/home/{{ ansible_ssh_user }}/dns/Corefile" --become
ansible -i ../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m copy -a "src=./cp-planta.saccilotto.com.db dest=/home/{{ ansible_ssh_user }}/dns/zones/cp-planta.saccilotto.com.db" --become

# Update DNS zone file with manager IP
ansible -i ../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m replace -a "path=/home/{{ ansible_ssh_user }}/dns/zones/cp-planta.saccilotto.com.db regexp='10\\.0\\.1\\.10' replace='{{ ansible_default_ipv4.address }}'" --become

# Redeploy the stacks
if [[ "$REGIONS" == "multi" ]]; then
    echo -e "${YELLOW}Redeploying stacks in primary and secondary regions...${NC}"
    ansible -i ../$INVENTORY_FILE primary_region --limit 1 -m shell -a "cd /home/{{ ansible_ssh_user }} && docker stack deploy --with-registry-auth --resolve-image always -c stack.yml CP-Planta-Primary" --become
    ansible -i ../$INVENTORY_FILE secondary_region --limit 1 -m shell -a "cd /home/{{ ansible_ssh_user }} && docker stack deploy --with-registry-auth --resolve-image always -c stack.yml CP-Planta-Secondary" --become
else
    echo -e "${YELLOW}Redeploying stack on manager node...${NC}"
    ansible -i ../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "cd /home/{{ ansible_ssh_user }} && docker stack deploy --with-registry-auth --resolve-image always -c stack.yml CP-Planta" --become
fi

# Update specific services if needed
STACK_PREFIX="CP-Planta"
if [[ "$REGIONS" == "multi" ]]; then
    PRIMARY_STACK="CP-Planta-Primary"
    SECONDARY_STACK="CP-Planta-Secondary"
else
    PRIMARY_STACK="CP-Planta"
fi

if [[ "$UPDATE_FRONTEND" == "true" ]]; then
    echo -e "${YELLOW}Updating frontend services...${NC}"
    if [[ "$REGIONS" == "multi" ]]; then
        ansible -i ../$INVENTORY_FILE primary_region --limit 1 -m shell -a "docker service update --force ${PRIMARY_STACK}_frontend" --become
        ansible -i ../$INVENTORY_FILE secondary_region --limit 1 -m shell -a "docker service update --force ${SECONDARY_STACK}_frontend" --become
    else
        ansible -i ../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "docker service update --force ${PRIMARY_STACK}_frontend" --become
    fi
fi

if [[ "$UPDATE_BACKEND" == "true" ]]; then
    echo -e "${YELLOW}Updating backend services...${NC}"
    if [[ "$REGIONS" == "multi" ]]; then
        ansible -i ../$INVENTORY_FILE primary_region --limit 1 -m shell -a "docker service update --force ${PRIMARY_STACK}_backend" --become
        ansible -i ../$INVENTORY_FILE secondary_region --limit 1 -m shell -a "docker service update --force ${SECONDARY_STACK}_backend" --become
    else
        ansible -i ../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "docker service update --force ${PRIMARY_STACK}_backend" --become
    fi
fi

if [[ "$UPDATE_DB" == "true" ]]; then
    echo -e "${YELLOW}Updating database services...${NC}"
    if [[ "$REGIONS" == "multi" ]]; then
        ansible -i ../$INVENTORY_FILE primary_region --limit 1 -m shell -a "docker service update --force ${PRIMARY_STACK}_postgres_primary ${PRIMARY_STACK}_postgres_replica ${PRIMARY_STACK}_pgadmin ${PRIMARY_STACK}_pgbouncer" --become
        ansible -i ../$INVENTORY_FILE secondary_region --limit 1 -m shell -a "docker service update --force ${SECONDARY_STACK}_postgres_replica ${SECONDARY_STACK}_pgadmin ${SECONDARY_STACK}_pgbouncer" --become
    else
        ansible -i ../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "docker service update --force ${PRIMARY_STACK}_postgres_primary ${PRIMARY_STACK}_postgres_replica ${PRIMARY_STACK}_pgadmin ${PRIMARY_STACK}_pgbouncer" --become
    fi
fi

# Update DNS service if needed
echo -e "${YELLOW}Updating DNS service...${NC}"
if [[ "$REGIONS" == "multi" ]]; then
    ansible -i ../$INVENTORY_FILE primary_region --limit 1 -m shell -a "docker service update --force ${PRIMARY_STACK}_dns" --become
    ansible -i ../$INVENTORY_FILE secondary_region --limit 1 -m shell -a "docker service update --force ${SECONDARY_STACK}_dns" --become
else
    ansible -i ../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "docker service update --force ${PRIMARY_STACK}_dns" --become
fi

# Wait for services to stabilize
echo -e "${YELLOW}Waiting for services to stabilize...${NC}"
sleep 15

# Show service status
if [[ "$REGIONS" == "multi" ]]; then
    echo -e "${YELLOW}Primary region service status:${NC}"
    ansible -i ../$INVENTORY_FILE primary_region --limit 1 -m shell -a "docker service ls" --become
    echo -e "${YELLOW}Secondary region service status:${NC}"
    ansible -i ../$INVENTORY_FILE secondary_region --limit 1 -m shell -a "docker service ls" --become
else
    echo -e "${YELLOW}Service status:${NC}"
    ansible -i ../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "docker service ls" --become
fi

# Update deployment marker
git rev-parse HEAD > ../.last_deployment
echo -e "${GREEN}Updated deployment marker to current commit.${NC}"

cd ..
echo -e "${GREEN}Update process completed on $PROVIDER using $REGIONS region mode.${NC}"