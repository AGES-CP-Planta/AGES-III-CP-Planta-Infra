#!/bin/bash

# Get PgAdmin port from environment or use default
PGADMIN_PORT=${PGADMIN_LISTEN_PORT:-5050}
echo "PgAdmin is configured to listen on port: $PGADMIN_PORT"

# Wait for PgAdmin to fully initialize
until curl -s "http://localhost:$PGADMIN_PORT/api/v1/servers" 2>/dev/null; do
  echo "Waiting for PgAdmin to initialize..."
  sleep 5
done

echo "PgAdmin is now running. Setting up server connections..."

# Define the server configurations
SERVER_CONFIGS=(
  '{
    "name": "CP-Planta DB (PgBouncer)",
    "group": "Servers",
    "host": "'${DB_HOST_BOUNCER:-pgbouncer}'",
    "port": '${DB_PORT_BOUNCER:-6432}',
    "username": "'${DB_USERNAME:-postgres}'",
    "password": "'${DB_PASSWORD:-postgres}'",
    "maintenance_db": "'${DB_DATABASE:-postgres}'",
    "comment": "Connection through PgBouncer"
  }'
  '{
    "name": "PostgreSQL Primary",
    "group": "Servers",
    "host": "'${DB_HOST_PRIMARY:-postgres_primary}'",
    "port": '${DB_PORT_PRIMARY:-5432}',
    "username": "'${DB_USERNAME:-postgres}'",
    "password": "'${DB_PASSWORD:-postgres}'",
    "maintenance_db": "'${DB_DATABASE:-postgres}'",
    "comment": "Direct connection to Primary"
  }'
)

# Send server configurations to the PgAdmin API
for config in "${SERVER_CONFIGS[@]}"; do
  echo "Adding server: $(echo $config | grep -o '"name": "[^"]*"')"
  response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "$config" \
    "http://localhost:$PGADMIN_PORT/api/v1/servers" 2>&1)
  
  if [[ "$response" == *"success"* ]]; then
    echo "Server added successfully"
  else
    echo "Failed to add server: $response"
  fi
done

echo "Server setup completed."

# Keep the script running if needed (PgAdmin will continue running)
if [[ "${KEEP_RUNNING:-false}" == "true" ]]; then
  echo "Keeping setup script alive..."
  tail -f /dev/null
fi