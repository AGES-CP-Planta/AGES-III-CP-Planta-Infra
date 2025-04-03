#!/bin/bash
set -e

# Function to replace environment variables in configuration files
replace_env_vars() {
    local file=$1
    
    # Substituting environment variables in repmgr.conf
    if [[ -n "$NODE_ID" ]]; then
        sed -i "s/NODE_ID/$NODE_ID/" $file
    fi
    
    if [[ -n "$NODE_NAME" ]]; then
        sed -i "s/NODE_NAME/$NODE_NAME/" $file
    fi
    
    if [[ -n "$NODE_HOST" ]]; then
        sed -i "s/NODE_HOST/$NODE_HOST/" $file
    fi
}

# Initialize primary server
init_primary() {
    echo "Initializing primary PostgreSQL server..."
    
    # Create data directory if it doesn't exist
    if [[ ! -s "$PGDATA/PG_VERSION" ]]; then
        echo "Initializing database..."
        initdb -D $PGDATA -U postgres
        
        # Copy the configuration files from /etc/postgresql to data directory
        cp /etc/postgresql/postgresql.conf "$PGDATA/"
        cp /etc/postgresql/pg_hba.conf "$PGDATA/"
        
        # Ensure replication settings are properly set
        echo "Checking replication configuration..."
        if ! grep -q "replication_slot" "$PGDATA/postgresql.conf"; then
            echo "Adding hot standby configuration..."
            echo "hot_standby = on" >> "$PGDATA/postgresql.conf"
        fi
    fi
    
    # Start PostgreSQL temporarily to create replication slot
    echo "Starting PostgreSQL temporarily to create replication slot..."
    pg_ctl -D "$PGDATA" -w start
    
    # Create replication slot if it doesn't exist
    echo "Creating replication slot if needed..."
    psql -U postgres -c "SELECT pg_create_physical_replication_slot('replication_slot') WHERE NOT EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = 'replication_slot');"
    
    # Stop PostgreSQL
    echo "Stopping temporary PostgreSQL instance..."
    pg_ctl -D "$PGDATA" -w stop
}

# Initialize replica server
init_replica() {
    echo "Initializing replica PostgreSQL server..."
    
    # Remove data directory if it exists
    rm -rf "$PGDATA"/*
    
    echo "Connecting to primary server at $REPLICATE_FROM..."
    # Try to connect to primary and perform base backup
    until pg_basebackup -h $REPLICATE_FROM -D "$PGDATA" -U postgres -X stream -P; do
        echo "Waiting for primary node to be ready..."
        sleep 5
    done
    
    # Create recovery configuration
    echo "Setting up replication configuration..."
    cat > "$PGDATA/postgresql.auto.conf" <<EOF
primary_conninfo = 'host=$REPLICATE_FROM port=5432 user=postgres password=$POSTGRES_PASSWORD application_name=$NODE_NAME'
primary_slot_name = 'replication_slot'
hot_standby = on
EOF

    # Create standby signal file
    touch "$PGDATA/standby.signal"
}

# Main entrypoint logic
if [[ "$ROLE" == "primary" ]]; then
    echo "Configuring node as PRIMARY"
    init_primary
elif [[ "$ROLE" == "replica" ]]; then
    echo "Configuring node as REPLICA"
    if [[ -z "$REPLICATE_FROM" ]]; then
        echo "Error: REPLICATE_FROM environment variable not set. Cannot configure replica."
        exit 1
    fi
    
    # Wait for the primary to be available
    until pg_isready -h $REPLICATE_FROM -U postgres; do
        echo "Waiting for primary node to be available..."
        sleep 5
    done
    
    init_replica
else
    echo "ROLE not specified (primary or replica). Running as standalone instance."
    # Default initialization
    if [[ ! -s "$PGDATA/PG_VERSION" ]]; then
        echo "Initializing database as standalone..."
        initdb -D $PGDATA -U postgres
        cp /etc/postgresql/postgresql.conf "$PGDATA/"
        cp /etc/postgresql/pg_hba.conf "$PGDATA/"
    fi
fi

# Ensure proper ownership of the data directory
echo "Setting proper ownership for data directory..."
chown -R postgres:postgres "$PGDATA"

# Copy repmgr.conf if it exists
if [[ -f /etc/repmgr.conf ]]; then
    echo "Setting up repmgr configuration..."
    cp /etc/repmgr.conf /var/lib/postgresql/repmgr.conf
    replace_env_vars /var/lib/postgresql/repmgr.conf
    chown postgres:postgres /var/lib/postgresql/repmgr.conf
fi

# Start PostgreSQL
echo "Starting PostgreSQL server..."
exec postgres -D $PGDATA