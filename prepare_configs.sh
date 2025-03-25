#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENV="production"
DEPLOY_TYPE="swarm"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            ENV="$2"
            shift 2
            ;;
        --deploy-type)
            DEPLOY_TYPE="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}Preparing configuration for environment: ${ENV}, deployment type: ${DEPLOY_TYPE}${NC}"

# Create necessary directories
mkdir -p ./deployment/${DEPLOY_TYPE}/config

# Process PostgreSQL configuration
process_postgresql_config() {
    local target_dir="./deployment/${DEPLOY_TYPE}/config/postgresql"
    mkdir -p "$target_dir"
    
    # Copy base configuration
    cp ./deployment/ansible/roles/database/postgresql/postgresql.conf "$target_dir/"
    cp ./deployment/ansible/roles/database/postgresql/pg_hba.conf "$target_dir/"
    cp ./deployment/ansible/roles/database/postgresql/repmgr.conf "$target_dir/"
    
    # Apply environment-specific modifications if any
    if [ -f "./config/environments/${ENV}/postgresql.conf.patch" ]; then
        echo -e "${YELLOW}Applying environment-specific PostgreSQL configuration...${NC}"
        patch "$target_dir/postgresql.conf" "./config/environments/${ENV}/postgresql.conf.patch"
    fi
}

# Process PgBouncer configuration
process_pgbouncer_config() {
    local target_dir="./deployment/${DEPLOY_TYPE}/config/pgbouncer"
    mkdir -p "$target_dir"
    
    # Copy base configuration
    cp ./deployment/ansible/roles/database/pgbouncer/pgbouncer.ini "$target_dir/"
    cp ./deployment/ansible/roles/database/pgbouncer/userlist.txt "$target_dir/"
    
    # Apply environment-specific modifications if any
    if [ -f "./config/environments/${ENV}/pgbouncer.ini.patch" ]; then
        echo -e "${YELLOW}Applying environment-specific PgBouncer configuration...${NC}"
        patch "$target_dir/pgbouncer.ini" "./config/environments/${ENV}/pgbouncer.ini.patch"
    fi
}

# Process Docker Swarm or Kubernetes configuration
process_deployment_config() {
    if [ "$DEPLOY_TYPE" == "swarm" ]; then
        # Process Docker Swarm configuration
        echo -e "${YELLOW}Preparing Docker Swarm configuration...${NC}"
        
        # Copy base stack file
        cp ./deployment/swarm/stack.yml ./deployment/swarm/config/
        
        # Apply environment-specific modifications if any
        if [ -f "./config/environments/${ENV}/stack.yml.patch" ]; then
            echo -e "${YELLOW}Applying environment-specific stack configuration...${NC}"
            patch "./deployment/swarm/config/stack.yml" "./config/environments/${ENV}/stack.yml.patch"
        fi
        
        # Process environment variables
        if [ -f "./config/environments/${ENV}.env" ]; then
            echo -e "${YELLOW}Processing environment variables...${NC}"
            source "./config/environments/${ENV}.env"
            
            # Replace environment variables in stack.yml
            envsubst < "./deployment/swarm/config/stack.yml" > "./deployment/swarm/config/stack.yml.tmp"
            mv "./deployment/swarm/config/stack.yml.tmp" "./deployment/swarm/config/stack.yml"
        fi
    else
        # Process Kubernetes configuration
        echo -e "${YELLOW}Preparing Kubernetes configuration...${NC}"
        
        # Copy base manifests
        mkdir -p ./deployment/kubernetes/config/
        cp -r ./deployment/kubernetes/manifests/* ./deployment/kubernetes/config/
        
        # Apply environment-specific modifications if any
        if [ -d "./config/environments/${ENV}/kubernetes" ]; then
            echo -e "${YELLOW}Applying environment-specific Kubernetes configuration...${NC}"
            cp -r "./config/environments/${ENV}/kubernetes/"* "./deployment/kubernetes/config/"
        fi
    fi
}

# Execute configuration processing
process_postgresql_config
process_pgbouncer_config
process_deployment_config

echo -e "${GREEN}Configuration preparation complete for environment: ${ENV}, deployment type: ${DEPLOY_TYPE}${NC}"

exit 0