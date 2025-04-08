#!/bin/sh
set -e

# Start CoreDNS with the configuration
exec /coredns -conf /etc/coredns/Corefile