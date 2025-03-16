#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}CP-Planta Infrastructure Deployment${NC}"
echo -e "${YELLOW}Updating swarm deployment with PostgreSQL replication...${NC}"

# Create necessary directories
mkdir -p ./config/replication ./config/pgbouncer

# Copy configuration files for PostgreSQL replication
cat > ./config/replication/repmgr.conf << 'EOF'
node_id=NODE_ID
node_name='NODE_NAME'
conninfo='host=NODE_HOST user=postgres dbname=postgres connect_timeout=10'
data_directory='/var/lib/postgresql/data'
use_replication_slots=yes
failover=automatic
promote_command='/usr/bin/repmgr standby promote -f /etc/repmgr.conf --log-to-file'
follow_command='/usr/bin/repmgr standby follow -f /etc/repmgr.conf --log-to-file --upstream-node-id=%n'
log_level=INFO
log_facility=STDERR
EOF

cat > ./config/replication/postgresql.conf << 'EOF'
# PostgreSQL Configuration File for Replication
listen_addresses = '*'
port = 5432
max_connections = 200
wal_level = replica
max_wal_senders = 10
max_replication_slots = 10
wal_keep_size = 128MB
hot_standby = on
hot_standby_feedback = on
EOF

cat > ./config/replication/pg_hba.conf << 'EOF'
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             postgres                                peer
local   all             all                                     md5
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
host    all             all             0.0.0.0/0               md5
host    replication     postgres        0.0.0.0/0               md5
EOF

cat > ./config/pgbouncer/pgbouncer.ini << 'EOF'
[databases]
postgres = host=postgres_primary port=5432 dbname=postgres user=postgres password=postgres
postgres_ro = host=postgres_replica port=5432 dbname=postgres user=postgres password=postgres

[pgbouncer]
listen_addr = *
listen_port = 6432
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = session
max_client_conn = 200
default_pool_size = 50
min_pool_size = 10
reserve_pool_size = 20
reserve_pool_timeout = 5
server_reset_query = DISCARD ALL
server_check_query = SELECT 1
EOF

cat > ./config/pgbouncer/userlist.txt << 'EOF'
"postgres" "md53175bce1d3201d16594cebf9d7eb3f9d"
EOF

# Update the swarm ansible playbook
echo -e "${YELLOW}Updating Ansible playbook to support replication...${NC}"

cat > ./swarm_postgres_replication.yml << 'EOF'
- name: Configure PostgreSQL Replication on Docker Swarm
  hosts: all
  become: yes
  vars:
    manager_node: "{{ groups['instance1'][0] }}"
    ansible_python_interpreter: /usr/bin/python3
  
  tasks:
  - name: Create config directories
    file:
      path: "{{ item }}"
      state: directory
      mode: '0755'
    loop:
      - /home/{{ ansible_ssh_user }}/config/replication
      - /home/{{ ansible_ssh_user }}/config/pgbouncer
    delegate_to: "{{ manager_node }}"
    run_once: true
  
  - name: Copy replication and pgbouncer config files
    copy:
      src: "{{ item.src }}"
      dest: "{{ item.dest }}"
      mode: "0644"
    loop:
      - { src: ./config/replication/repmgr.conf, dest: /home/{{ ansible_ssh_user }}/config/replication/repmgr.conf }
      - { src: ./config/replication/postgresql.conf, dest: /home/{{ ansible_ssh_user }}/config/replication/postgresql.conf }
      - { src: ./config/replication/pg_hba.conf, dest: /home/{{ ansible_ssh_user }}/config/replication/pg_hba.conf }
      - { src: ./config/pgbouncer/pgbouncer.ini, dest: /home/{{ ansible_ssh_user }}/config/pgbouncer/pgbouncer.ini }
      - { src: ./config/pgbouncer/userlist.txt, dest: /home/{{ ansible_ssh_user }}/config/pgbouncer/userlist.txt }
    delegate_to: "{{ manager_node }}"
    run_once: true
  
  - name: Setup environment variables for replication
    lineinfile:
      path: /home/{{ ansible_ssh_user }}/.bashrc
      line: "{{ item }}"
      create: yes
    loop:
      - "export PRIMARY_HOST={{ hostvars[groups['instance1'][0]].ansible_host | default(groups['instance1'][0]) }}"
      - "export REPLICA_HOST={{ hostvars[groups['instance2'][0]].ansible_host | default(groups['instance2'][0]) }}"
    delegate_to: "{{ manager_node }}"
    run_once: true
  
  - name: Source environment variables
    shell: source /home/{{ ansible_ssh_user }}/.bashrc
    args:
      executable: /bin/bash
    delegate_to: "{{ manager_node }}"
    run_once: true
  
  - name: Update docker-compose.yml with replication settings
    copy:
      src: ./enhanced-stack.yml
      dest: /home/{{ ansible_ssh_user }}/stack.yml
    delegate_to: "{{ manager_node }}"
    run_once: true
  
  - name: Redeploy stack with replication
    shell: docker stack deploy --with-registry-auth -c /home/{{ ansible_ssh_user }}/stack.yml CP-Planta
    args:
      chdir: /home/{{ ansible_ssh_user }}
    delegate_to: "{{ manager_node }}"
    run_once: true
  
  - name: Wait for services to initialize
    pause:
      seconds: 30
    delegate_to: "{{ manager_node }}"
    run_once: true
  
  - name: Display service status
    shell: docker service ls
    register: service_status
    delegate_to: "{{ manager_node }}"
    run_once: true
  
  - name: Show service status
    debug:
      var: service_status.stdout_lines
    delegate_to: "{{ manager_node }}"
    run_once: true
EOF

echo -e "${GREEN}Configuration files and playbook created.${NC}"
echo -e "${YELLOW}Now you can add the replication setup to your deployment process by running:${NC}"
echo -e "${BLUE}ansible-playbook -i static_ip.ini ./swarm_postgres_replication.yml${NC}"
echo -e "${YELLOW}This will update your Docker Swarm stack with PostgreSQL replication support!${NC}"