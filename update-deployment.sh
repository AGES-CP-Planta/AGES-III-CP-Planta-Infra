#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}CP-Planta Deployment Update Script${NC}"

# Get the manager IP from static_ip.ini
if [ -f "static_ip.ini" ]; then
    MANAGER_IP=$(grep -A1 '\[instance1\]' static_ip.ini | tail -n1 | awk '{print $1}')
    MANAGER_KEY=$(grep -A1 '\[instance1\]' static_ip.ini | tail -n1 | grep -o 'ansible_ssh_private_key_file=[^ ]*' | cut -d= -f2)
    echo -e "${BLUE}Found manager IP: $MANAGER_IP${NC}"
else
    echo -e "${RED}Error: static_ip.ini not found${NC}"
    exit 1
fi

# Check if SSH key exists
if [ ! -f "$MANAGER_KEY" ]; then
    echo -e "${RED}Error: SSH key file $MANAGER_KEY not found${NC}"
    exit 1
fi

# Step 1: Copy updated stack.yml to manager node
echo -e "\n${YELLOW}Copying updated stack.yml to manager node...${NC}"
scp -i $MANAGER_KEY Swarm/stack.yml ubuntu@$MANAGER_IP:/home/ubuntu/stack.yml

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to copy stack.yml${NC}"
    exit 1
fi
echo -e "${GREEN}Successfully copied stack.yml${NC}"

# Step 2: Create DNS directories if they don't exist
echo -e "\n${YELLOW}Setting up DNS directories...${NC}"
ssh -i $MANAGER_KEY ubuntu@$MANAGER_IP "mkdir -p /home/ubuntu/dns/zones"

# Step 3: Copy updated DNS files
echo -e "\n${YELLOW}Copying DNS configuration files...${NC}"
scp -i $MANAGER_KEY Swarm/Corefile ubuntu@$MANAGER_IP:/home/ubuntu/dns/Corefile
scp -i $MANAGER_KEY Swarm/cpplanta.duckdns.org.db ubuntu@$MANAGER_IP:/home/ubuntu/dns/zones/cpplanta.duckdns.org.db

# Step 4: Update DNS zone file with correct IP
echo -e "\n${YELLOW}Updating zone file with manager IP...${NC}"
ssh -i $MANAGER_KEY ubuntu@$MANAGER_IP "sed -i 's/10\.0\.1\.10/$MANAGER_IP/g' /home/ubuntu/dns/zones/cpplanta.duckdns.org.db"

# Step 5: Deploy updated stack
echo -e "\n${YELLOW}Deploying updated stack...${NC}"
ssh -i $MANAGER_KEY ubuntu@$MANAGER_IP "docker stack deploy --with-registry-auth --resolve-image always -c /home/ubuntu/stack.yml CP-Planta"

if [ $? -ne 0 ]; then
    echo -e "${RED}Stack deployment failed${NC}"
    exit 1
fi
echo -e "${GREEN}Stack deployed successfully${NC}"

# Step 6: Force update services
echo -e "\n${YELLOW}Updating services...${NC}"
ssh -i $MANAGER_KEY ubuntu@$MANAGER_IP "docker service update --force CP-Planta_backend"
ssh -i $MANAGER_KEY ubuntu@$MANAGER_IP "docker service update --force CP-Planta_frontend"
ssh -i $MANAGER_KEY ubuntu@$MANAGER_IP "docker service update --force CP-Planta_dns"
ssh -i $MANAGER_KEY ubuntu@$MANAGER_IP "docker service update --force CP-Planta_pgadmin"

# Step 7: Wait for services to stabilize
echo -e "\n${YELLOW}Waiting for services to stabilize...${NC}"
sleep 20

# Step 8: Show service status
echo -e "\n${YELLOW}Current service status:${NC}"
ssh -i $MANAGER_KEY ubuntu@$MANAGER_IP "docker service ls"

echo -e "\n${GREEN}Deployment update complete!${NC}"
echo -e "${YELLOW}Your services should now be accessible at:${NC}"
echo -e "${BLUE}Frontend: https://cpplanta.duckdns.org${NC}"
echo -e "${BLUE}API: https://api.cpplanta.duckdns.org${NC}"
echo -e "${BLUE}PgAdmin: https://pgadmin.cpplanta.duckdns.org${NC}"
echo -e "\n${YELLOW}Note: It may take a few minutes for DNS changes and SSL certificates to propagate.${NC}"