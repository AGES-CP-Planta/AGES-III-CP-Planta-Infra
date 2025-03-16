#!/bin/bash

echo "Checking deploy.sh..."
grep -n "cd " deploy.sh
grep -n "ansible-playbook" deploy.sh

echo -e "\nChecking update-deployment.sh..."
grep -n "cd " update-deployment.sh
grep -n "ansible-playbook" update-deployment.sh

echo -e "\nChecking swarm_setup.yml..."
grep -n "src:" deployment/ansible/playbooks/swarm_setup.yml
grep -n "dest:" deployment/ansible/playbooks/swarm_setup.yml

echo -e "\nChecking stack.yml..."
grep -n "volumes:" deployment/swarm/stack.yml

echo -e "\nChecking replication_setup.sh..."
grep -n "config/" deployment/swarm/replication_setup.sh
