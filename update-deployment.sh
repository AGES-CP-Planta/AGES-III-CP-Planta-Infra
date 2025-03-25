#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
PROVIDER="aws"
SERVICE="all"
FORCE_UPDATE=false
UPDATE_INFRA=false
CLEAN_DOCKER=true  # Option for Docker cleanup
ENABLE_ROLLBACK=true  # Enable rollback on failure
UPDATE_LOG="update_$(date +%Y%m%d_%H%M%S).log"

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
    echo -e "  -c, --no-clean    Skip Docker cleanup (prune unused containers, images, etc.)"
    echo -e "  -n, --no-rollback Disable automatic rollback on failure"
    echo -e "  -h, --help        Show this help message"
    echo ""
    echo -e "Example: ./update-deployment.sh --provider aws --service backend --force"
}

# Error handling function
function handle_error {
    local error_msg=$1
    local stage=$2
    
    echo -e "${RED}ERROR during $stage: $error_msg${NC}"
    
    # Log error
    echo "[$(date)] ERROR during $stage: $error_msg" >> $UPDATE_LOG
    
    # Optional rollback logic based on stage
    if [[ "$ENABLE_ROLLBACK" == "true" ]]; then
        echo -e "${YELLOW}Attempting rollback...${NC}"
        if [[ "$stage" == "infrastructure" ]]; then
            echo -e "${YELLOW}WARNING: Infrastructure rollback not implemented. Manual intervention may be required.${NC}"
            echo "[$(date)] WARNING: Infrastructure rollback not implemented." >> $UPDATE_LOG
        elif [[ "$stage" == "service_update" ]]; then
            echo -e "${YELLOW}Rolling back service updates...${NC}"
            echo "[$(date)] Rolling back service updates..." >> $UPDATE_LOG
            
            # Restore previous stack deployment if available
            if [[ -f "deployment/ansible/playbooks/previous_stack.yml" ]]; then
                ansible -i $INVENTORY_FILE $MANAGER_GROUP --limit 1 -m copy -a "src=deployment/ansible/playbooks/previous_stack.yml dest=/home/{{ ansible_ssh_user }}/stack.yml" --become
                ansible -i $INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "cd /home/{{ ansible_ssh_user }} && docker stack deploy --with-registry-auth -c stack.yml CP-Planta" --become
                echo -e "${GREEN}Stack rollback completed.${NC}"
                echo "[$(date)] Stack rollback completed." >> $UPDATE_LOG
            else
                echo -e "${RED}No previous stack file found for rollback.${NC}"
                echo "[$(date)] No previous stack file found for rollback." >> $UPDATE_LOG
            fi
        fi
    fi
    
    echo -e "${RED}Update failed. See $UPDATE_LOG for details.${NC}"
    exit 1
}

# Logging function
function log_message {
    local message=$1
    local level=${2:-INFO}
    
    echo "[$(date)] [$level] $message" >> $UPDATE_LOG
    
    if [[ "$level" == "INFO" ]]; then
        echo -e "${BLUE}$message${NC}"
    elif [[ "$level" == "SUCCESS" ]]; then
        echo -e "${GREEN}$message${NC}"
    elif [[ "$level" == "WARNING" ]]; then
        echo -e "${YELLOW}$message${NC}"
    elif [[ "$level" == "ERROR" ]]; then
        echo -e "${RED}$message${NC}"
    fi
}

# Verification function
function verify_services {
    log_message "Verifying service health..." "INFO"
    
    # Check that services are running
    FAILED_SERVICES=$(ansible -i $INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "docker service ls --format '{{.Name}} {{.Replicas}}' | grep -v '[0-9]/[0-9]'" --become)
    
    if [[ -n "$FAILED_SERVICES" ]]; then
        log_message "The following services have issues:" "ERROR"
        log_message "$FAILED_SERVICES" "ERROR"
        return 1
    fi
    
    # Check service health where available
    UNHEALTHY_SERVICES=$(ansible -i $INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "docker service ls --format '{{.Name}}' | xargs -I {} docker service ps {} --format '{{.Name}} {{.CurrentState}}' | grep -i unhealthy" --become)
    
    if [[ -n "$UNHEALTHY_SERVICES" ]]; then
        log_message "The following services are unhealthy:" "ERROR"
        log_message "$UNHEALTHY_SERVICES" "ERROR"
        return 1
    fi
    
    log_message "All services appear healthy" "SUCCESS"
    return 0
}

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
        -c|--no-clean)
            CLEAN_DOCKER=false
            shift
            ;;
        -n|--no-rollback)
            ENABLE_ROLLBACK=false
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_message "Unknown option: $1" "ERROR"
            show_help
            exit 1
            ;;
    esac
done

# Initialize log file
log_message "Starting update process for provider: $PROVIDER, service: $SERVICE" "INFO"
log_message "Force update: $FORCE_UPDATE, Infrastructure update: $UPDATE_INFRA, Clean Docker: $CLEAN_DOCKER" "INFO"

# Set project vars
if [[ -f .env ]]; then
    log_message "Loading environment variables from .env file..." "INFO"
    export $(grep -v '^#' .env | xargs)
else
    log_message "Error: .env file not found. Create it before running this script." "ERROR"
    handle_error ".env file not found" "environment_setup"
fi

# Detect Git changes to determine what needs updating
if [[ "$FORCE_UPDATE" == "false" ]]; then
    log_message "Detecting changes since last deployment..." "INFO"
    
    # Initialize or update last deployment marker
    if [[ ! -f .last_deployment ]]; then
        git rev-parse HEAD > .last_deployment
        log_message "No previous deployment marker found. Will perform full update." "WARNING"
        FORCE_UPDATE=true
    else
        LAST_DEPLOY=$(cat .last_deployment)
        
        # Check for infrastructure changes
        INFRA_CHANGES=$(git diff --name-only $LAST_DEPLOY HEAD -- "terraform*")
        if [[ -n "$INFRA_CHANGES" && "$UPDATE_INFRA" == "false" ]]; then
            log_message "Infrastructure changes detected:" "WARNING"
            log_message "$INFRA_CHANGES" "INFO"
            log_message "Consider running with --infra flag to apply these changes." "WARNING"
        elif [[ -n "$INFRA_CHANGES" && "$UPDATE_INFRA" == "true" ]]; then
            log_message "Will apply infrastructure changes." "INFO"
        fi
        
        # Check for service-specific changes
        if [[ "$SERVICE" == "all" || "$SERVICE" == "frontend" ]]; then
            FRONTEND_CHANGES=$(git diff --name-only $LAST_DEPLOY HEAD -- "*frontend*" "deployment/swarm/*frontend*")
            if [[ -n "$FRONTEND_CHANGES" ]]; then
                log_message "Frontend changes detected. Will update frontend services." "INFO"
                UPDATE_FRONTEND=true
            fi
        fi
        
        if [[ "$SERVICE" == "all" || "$SERVICE" == "backend" ]]; then
            BACKEND_CHANGES=$(git diff --name-only $LAST_DEPLOY HEAD -- "*backend*" "deployment/swarm/*backend*")
            if [[ -n "$BACKEND_CHANGES" ]]; then
                log_message "Backend changes detected. Will update backend services." "INFO"
                UPDATE_BACKEND=true
            fi
        fi
        
        if [[ "$SERVICE" == "all" || "$SERVICE" == "db" ]]; then
            DB_CHANGES=$(git diff --name-only $LAST_DEPLOY HEAD -- "*postgres*" "*pgadmin*" "deployment/swarm/*postgres*" "deployment/swarm/*pgadmin*")
            if [[ -n "$DB_CHANGES" ]]; then
                log_message "Database changes detected. Will update database services." "INFO"
                UPDATE_DB=true
            fi
        fi
        
        # Check for general Swarm configuration changes
        SWARM_CHANGES=$(git diff --name-only $LAST_DEPLOY HEAD -- "deployment/swarm/*.yml" "deployment/swarm/*.yaml" "deployment/swarm/templates")
        if [[ -n "$SWARM_CHANGES" ]]; then
            log_message "Swarm configuration changes detected. Will update all services." "INFO"
            UPDATE_FRONTEND=true
            UPDATE_BACKEND=true
            UPDATE_DB=true
        fi
    fi
else
    log_message "Force update enabled. Will update all requested services." "INFO"
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
    log_message "Updating infrastructure with Terraform..." "INFO"
    
    if [[ "$PROVIDER" == "aws" ]]; then
        cd terraform/aws
    elif [[ "$PROVIDER" == "azure" ]]; then
        cd terraform/azure
    else
        log_message "Unsupported provider: $PROVIDER" "ERROR"
        handle_error "Unsupported provider" "infrastructure"
    fi
    
    terraform init || handle_error "Terraform initialization failed" "infrastructure"
    terraform plan -out=tf.plan || handle_error "Terraform plan failed" "infrastructure"
    
    log_message "Applying Terraform plan..." "INFO"
    terraform apply tf.plan || handle_error "Terraform apply failed" "infrastructure"
    
    # Save Terraform state
    log_message "Saving Terraform state..." "INFO"
    if [[ -d "../../.git" ]]; then
        mkdir -p ../../terraform-state
        cp terraform.tfstate ../../terraform-state/terraform-${PROVIDER}-$(date +%Y%m%d).tfstate
    fi
    
    cd ../..
    log_message "Infrastructure update completed successfully." "SUCCESS"
    
    # Updating the inventory file after infrastructure changes
    if [[ -f "terraform-state/terraform-${PROVIDER}-$(date +%Y%m%d).tfstate" ]]; then
        log_message "Updating inventory file from new infrastructure state..." "INFO"
        ./prepare_configs.sh --provider $PROVIDER || handle_error "Failed to update inventory" "infrastructure"
    fi
fi

# Determine inventory file
INVENTORY_FILE="static_ip.ini"

# Check if inventory file exists
if [[ ! -f "$INVENTORY_FILE" ]]; then
    log_message "Error: Inventory file $INVENTORY_FILE not found." "ERROR"
    log_message "Have you run ./deploy.sh first?" "WARNING"
    handle_error "Missing inventory file" "environment_setup"
fi

# Update Swarm services
cd deployment/ansible/playbooks

# Determine the manager node
MANAGER_GROUP="instance1"

# Use Ansible to get the manager node IP
MANAGER_IP=$(ansible -i ../../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "hostname -I | awk '{print \$1}'" | grep -v "CHANGED" | tr -d '[:space:]')

if [[ -z "$MANAGER_IP" ]]; then
    log_message "Error: Could not determine manager node IP." "ERROR"
    handle_error "Failed to get manager IP" "service_update"
fi

log_message "Manager node IP: $MANAGER_IP" "INFO"

# Save current stack file for rollback
log_message "Backing up current stack configuration for rollback..." "INFO"
ansible -i ../../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m fetch -a "src=/home/{{ ansible_ssh_user }}/stack.yml dest=./previous_stack.yml flat=yes" --become || log_message "Could not backup current stack file - rollback may not be possible" "WARNING"

# Function to clean up Docker resources
function clean_docker_resources {
    log_message "Cleaning up unused Docker resources..." "INFO"
    
    # Remove unused containers
    ansible -i ../../../$INVENTORY_FILE all -m shell -a "docker container prune -f" --become || log_message "Failed to prune containers" "WARNING"
    
    # Remove unused networks
    ansible -i ../../../$INVENTORY_FILE all -m shell -a "docker network prune -f" --become || log_message "Failed to prune networks" "WARNING"
    
    # Remove unused volumes (careful with this one - only if you're sure data is backed up)
    ansible -i ../../../$INVENTORY_FILE all -m shell -a "docker volume ls -qf dangling=true | xargs -r docker volume rm" --become || log_message "Failed to prune volumes" "WARNING"
    
    # Remove unused images
    ansible -i ../../../$INVENTORY_FILE all -m shell -a "docker image prune -f" --become || log_message "Failed to prune images" "WARNING"
    
    log_message "Docker cleanup completed." "SUCCESS"
}

# Copy updated stack files if needed
log_message "Copying updated stack file to manager node..." "INFO"
ansible -i ../../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m copy -a "src=../swarm/stack.yml dest=/home/{{ ansible_ssh_user }}/stack.yml" --become || handle_error "Failed to copy stack file" "service_update"

# Update DNS configuration files if needed
log_message "Updating DNS configuration..." "INFO"
ansible -i ../../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m file -a "path=/home/{{ ansible_ssh_user }}/dns/zones state=directory mode=0755" --become || log_message "Failed to create DNS directory" "WARNING"
ansible -i ../../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m copy -a "src=../roles/networking/Corefile dest=/home/{{ ansible_ssh_user }}/dns/Corefile" --become || log_message "Failed to copy Corefile" "WARNING"
ansible -i ../../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m copy -a "src=../roles/networking/zones/cpplanta.duckdns.org.db dest=/home/{{ ansible_ssh_user }}/dns/zones/cpplanta.duckdns.org.db" --become || log_message "Failed to copy DNS zone file" "WARNING"

# Update DNS zone file with manager IP
ansible -i ../../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m replace -a "path=/home/{{ ansible_ssh_user }}/dns/zones/cpplanta.duckdns.org.db regexp='10\\.0\\.1\\.10' replace='{{ ansible_default_ipv4.address }}'" --become || log_message "Failed to update DNS zone file" "WARNING"

# Clean Docker resources if enabled
if [[ "$CLEAN_DOCKER" == "true" ]]; then
    clean_docker_resources
fi

# Redeploy the stack
log_message "Redeploying stack on manager node..." "INFO"
DEPLOY_RESULT=$(ansible -i ../../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "cd /home/{{ ansible_ssh_user }} && docker stack deploy --with-registry-auth --resolve-image always -c stack.yml CP-Planta" --become)
if [ $? -ne 0 ]; then
    log_message "Stack deployment failed: $DEPLOY_RESULT" "ERROR"
    handle_error "Stack deployment failed" "service_update"
fi
log_message "Stack deployed successfully" "SUCCESS"

# Update specific services if needed
STACK_PREFIX="CP-Planta"

if [[ "$UPDATE_FRONTEND" == "true" ]]; then
    log_message "Updating frontend services..." "INFO"
    ansible -i ../../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "docker service update --force ${STACK_PREFIX}_frontend" --become || handle_error "Frontend service update failed" "service_update"
    log_message "Frontend services updated successfully" "SUCCESS"
fi

if [[ "$UPDATE_BACKEND" == "true" ]]; then
    log_message "Updating backend services..." "INFO"
    ansible -i ../../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "docker service update --force ${STACK_PREFIX}_backend" --become || handle_error "Backend service update failed" "service_update"
    log_message "Backend services updated successfully" "SUCCESS"
fi

if [[ "$UPDATE_DB" == "true" ]]; then
    log_message "Updating database services..." "INFO"
    ansible -i ../../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "docker service update --force ${STACK_PREFIX}_postgres_primary" --become || log_message "Primary Postgres service update failed" "WARNING"
    ansible -i ../../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "docker service update --force ${STACK_PREFIX}_pgadmin" --become || log_message "PgAdmin service update failed" "WARNING"
    log_message "Database services updated successfully" "SUCCESS"
fi

# Update DNS service if needed
log_message "Updating DNS service..." "INFO"
ansible -i ../../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "docker service update --force ${STACK_PREFIX}_dns" --become || log_message "DNS service update failed" "WARNING"

# Wait for services to stabilize
log_message "Waiting for services to stabilize (30 seconds)..." "INFO"
sleep 30

# Verify services are running correctly
if ! verify_services; then
    handle_error "Service verification failed" "service_update"
fi

# Show service status
log_message "Service status:" "INFO"
SERVICE_STATUS=$(ansible -i ../../../$INVENTORY_FILE $MANAGER_GROUP --limit 1 -m shell -a "docker service ls" --become)
log_message "$SERVICE_STATUS" "INFO"

# Update deployment marker
git rev-parse HEAD > ../../../.last_deployment
log_message "Updated deployment marker to current commit." "SUCCESS"

cd ../../..
log_message "Update process completed successfully on $PROVIDER." "SUCCESS"
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}Update completed successfully!${NC}"
echo -e "${GREEN}Provider: $PROVIDER${NC}"
echo -e "${GREEN}Log file: $UPDATE_LOG${NC}"
echo -e "${GREEN}==========================================${NC}"

exit 0