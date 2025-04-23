#!/bin/bash
set -e

# Configure PostgreSQL
setup_postgresql() {
    # Create PGDATA directory if it doesn't exist
    if [[ ! -d "$PGDATA" ]]; then
        mkdir -p "$PGDATA"
    fi
    
    # If PGDATA is empty, initialize the database
    if [ -z "$(ls -A "$PGDATA")" ]; then
        echo "Initializing empty database directory..."
        initdb -D "$PGDATA"
        
        # Copy configuration files
        if [[ -f /etc/postgresql/postgresql.conf ]]; then
            cp /etc/postgresql/postgresql.conf "$PGDATA/"
        fi
        
        if [[ -f /etc/postgresql/pg_hba.conf ]]; then
            cp /etc/postgresql/pg_hba.conf "$PGDATA/"
        fi
    fi
}

# Configure based on role
if [[ "$ROLE" == "primary" ]]; then
    echo "Configuring node as PRIMARY"
    PGDATA=${PGDATA:-/var/lib/postgresql/data}
    setup_postgresql
    
    # Create replication slot if needed
    if [ -d "$PGDATA" ] && [ -f "$PGDATA/PG_VERSION" ]; then
        # Start PostgreSQL temporarily
        pg_ctl -D "$PGDATA" -w start
        
        # Create replication slot if it doesn't exist
        psql -c "SELECT 1 FROM pg_replication_slots WHERE slot_name = 'replication_slot'" | grep -q 1 || \
        psql -c "SELECT pg_create_physical_replication_slot('replication_slot', true, false);"
        
        # Stop PostgreSQL
        pg_ctl -D "$PGDATA" -w stop
    fi
    
elif [[ "$ROLE" == "replica" ]]; then
    echo "Configuring node as REPLICA"
    PGDATA=${PGDATA:-/var/lib/postgresql/data}
    
    # Check if database is already initialized as replica
    if [ -d "$PGDATA" ] && [ -f "$PGDATA/PG_VERSION" ] && [ -f "$PGDATA/standby.signal" ]; then
        echo "Database already initialized as replica"
    else
        # Clear data directory and set up replica
        rm -rf "$PGDATA"/*
        
        until pg_basebackup -h "$REPLICATE_FROM" -D "$PGDATA" -U postgres -X stream -P; do
            echo "Waiting for primary to be ready..."
            sleep 5
        done
        
        # Create standby configuration
        cat > "$PGDATA/postgresql.auto.conf" << CONF
primary_conninfo = 'host=$REPLICATE_FROM port=5432 user=postgres password=$POSTGRES_PASSWORD application_name=replica'
primary_slot_name = 'replication_slot'
hot_standby = on
CONF
        
        # Create standby signal file
        touch "$PGDATA/standby.signal"
    fi
else
    # Default standalone mode
    PGDATA=${PGDATA:-/var/lib/postgresql/data}
    setup_postgresql
fi

# Start PostgreSQL
echo "Starting PostgreSQL..."
exec postgres -D "$PGDATA"