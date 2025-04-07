#!/bin/bash
set -e

# Replace environment variables in config
envsubst < /etc/pgbouncer/pgbouncer.ini.template > /etc/pgbouncer/pgbouncer.ini

# Start pgbouncer
exec pgbouncer /etc/pgbouncer/pgbouncer.ini