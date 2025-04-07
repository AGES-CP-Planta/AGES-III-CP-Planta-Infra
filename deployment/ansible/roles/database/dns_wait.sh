#!/bin/bash
set -e

DNS_HOST=${DNS_HOST:-dns}
MAX_ATTEMPTS=${MAX_ATTEMPTS:-30}
SLEEP_TIME=${SLEEP_TIME:-2}

echo "Waiting for DNS service at $DNS_HOST to be ready..."
attempt=1

while [ $attempt -le $MAX_ATTEMPTS ]; do
  echo "Attempt $attempt/$MAX_ATTEMPTS: Checking DNS resolution..."
  
  # Try to resolve the service hostname
  if nslookup postgres_primary $DNS_HOST >/dev/null 2>&1; then
    echo "DNS is operational! Service discovery is working."
    exit 0
  fi
  
  echo "DNS not ready yet. Waiting $SLEEP_TIME seconds..."
  sleep $SLEEP_TIME
  attempt=$((attempt + 1))
done

echo "DNS resolution failed after $MAX_ATTEMPTS attempts."
echo "This could cause service connectivity issues."
echo "Continuing startup, but services may fail to connect properly."
exit 0  # Exiting with 0 to not block container startup