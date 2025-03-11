#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# DuckDNS configuration
DUCKDNS_TOKEN="ab25d043-0943-4338-88c7-315b3973ca90"
DOMAINS=("cpplanta" "api.cpplanta" "pgadmin.cpplanta")

# Get server's public IP
SERVER_IP=$(curl -s https://api.ipify.org)
echo -e "${BLUE}Current server IP: $SERVER_IP${NC}"

# Update each domain
for DOMAIN in "${DOMAINS[@]}"; do
    echo -e "${YELLOW}Updating $DOMAIN.duckdns.org...${NC}"
    UPDATE_RESULT=$(curl -s "https://www.duckdns.org/update?domains=$DOMAIN&token=$DUCKDNS_TOKEN&ip=$SERVER_IP")
    
    if [ "$UPDATE_RESULT" = "OK" ]; then
        echo -e "${GREEN}Successfully updated $DOMAIN.duckdns.org to point to $SERVER_IP${NC}"
    else
        echo -e "${RED}Failed to update $DOMAIN.duckdns.org: $UPDATE_RESULT${NC}"
    fi
done

# Create a crontab entry to run this script every hour
SCRIPT_PATH=$(realpath "$0")
CRON_ENTRY="0 * * * * $SCRIPT_PATH"

if ! (crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH"); then
    echo -e "${YELLOW}Adding cron job to update DuckDNS hourly...${NC}"
    (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
    echo -e "${GREEN}Cron job added!${NC}"
else
    echo -e "${BLUE}Cron job already exists.${NC}"
fi

echo -e "${GREEN}DuckDNS update complete!${NC}"