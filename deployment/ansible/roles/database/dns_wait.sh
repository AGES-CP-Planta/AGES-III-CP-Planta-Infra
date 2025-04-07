#!/bin/bash
set -e

DNS_HOST=${DNS_HOST:-dns}
MAX_ATTEMPTS=${MAX_ATTEMPTS:-60}
SLEEP_TIME=${SLEEP_TIME:-5}

echo "Waiting for DNS service at $DNS_HOST to be ready..."
attempt=1

while [ $attempt -le $MAX_ATTEMPTS ]; do
  echo "Attempt $attempt/$MAX_ATTEMPTS: Checking DNS resolution..."
  
  # Try to resolve various service hostnames
  for host in postgres_primary postgres_replica pgbouncer; do
    if nslookup $host $DNS_HOST >/dev/null 2>&1; then
      echo "DNS is operational! Successfully resolved $host"
      HOST_IP=$(nslookup $host $DNS_HOST | grep -A1 "Name:" | tail -1 | awk '{print $2}')
      echo "$host resolves to $HOST_IP"
    else
      echo "Could not resolve $host yet"
      found=0
      break
    fi
    found=1
  done
  
  if [ "$found" = "1" ]; then
    echo "All required hosts resolved successfully. DNS is ready!"
    exit 0
  fi
  
  echo "DNS not ready yet. Waiting $SLEEP_TIME seconds..."
  sleep $SLEEP_TIME
  attempt=$((attempt + 1))
done

echo "DNS resolution failed after $MAX_ATTEMPTS attempts."
echo "WARNING: This could cause service connectivity issues."
echo "Continuing startup, but services may fail to connect properly."
exit 0  # Exiting with 0 to not block container startup