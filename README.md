# CP-Planta Infrastructure

Cloud-agnostic Infrastructure as Code (IaC) and Configuration as Code (CaC) for the CP-Planta application, supporting AWS and Azure platforms with Docker Swarm orchestration.

![Banner](https://avatars.githubusercontent.com/u/202462667?s=200&v=4)

## Overview

CP-Planta Infrastructure provides an automated deployment pipeline for a containerized application stack with:

- **Multi-cloud support**: Deploy to AWS or Azure with the same code base
- **High availability**: Docker Swarm orchestration with service replication
- **Database resilience**: PostgreSQL with primary-replica replication
- **Connection pooling**: PgBouncer for optimized database connections
- **Automated DevOps**: GitHub Actions workflows for CI/CD
- **Secure access**: Automatic SSL certificate generation via Let's Encrypt

## Architecture

The infrastructure is designed as a multi-tier application with:

- **Frontend**: React.js application served through Traefik
- **Backend**: NestJS API with Prisma ORM
- **Database**: PostgreSQL with replication for high availability
- **Edge Router**: Traefik for SSL termination and routing
- **Monitoring**: Docker Swarm Visualizer

## Quick Start

### Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) (v1.0.0+)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) (v2.9+)
- [AWS CLI](https://aws.amazon.com/cli/) or [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Docker](https://docs.docker.com/engine/install/) (for local testing)

### Deployment

1. Clone the repository:

   ```bash
   git clone https://github.com/Saccilotto-AGES-Projects/AGES-III-CP-Planta-Infra.git
   cd AGES-III-CP-Planta-Infra
   ```

2. Create your environment file:

   ```bash
   ./secrets-manager.sh template
   cp .env.example .env
   # Edit .env with your cloud credentials
   ```

3. Deploy to your chosen cloud:

   ```bash
   # For AWS
   ./deploy.sh --provider aws
   
   # For Azure
   ./deploy.sh --provider azure
   ```

4. Access your application via the displayed endpoints:

   - Frontend: <https://cpplanta.duckdns.org>
   - API: <https://api.cpplanta.duckdns.org>
   - PgAdmin: <https://pgadmin.cpplanta.duckdns.org>
   - Visualizer: <https://viz.cpplanta.duckdns.org>

## Project Structure

```plaintext
CP-Planta-Infra/
├── .github/workflows/     # GitHub Actions workflows
├── terraform/             # Infrastructure as Code
│   ├── aws/               # AWS-specific configuration
│   ├── azure/             # Azure-specific configuration
│   └── modules/           # Reusable Terraform modules
├── deployment/            # Configuration as Code
│   ├── ansible/           # Ansible playbooks and roles
│   ├── swarm/             # Docker Swarm configuration
│   └── kubernetes/        # Kubernetes configuration (future)
├── docs/                  # Documentation
├── *.sh                   # Main deployment scripts
└── *.md                   # Documentation files
```

## Core Components

### Infrastructure Layer

- **Compute**: AWS EC2 or Azure VM instances
- **Networking**: VPC/VNet, Security Groups, Load Balancers
- **DNS**: DuckDNS for domain management

### Platform Layer

- **Container Orchestration**: Docker Swarm
- **Reverse Proxy**: Traefik with automatic SSL
- **Service Discovery**: Internal DNS with CoreDNS

### Application Layer

- **Database**: PostgreSQL with replication
- **Connection Pooling**: PgBouncer
- **Backend**: Node.js API containers
- **Frontend**: React.js static containers

## Key Features

### Multi-Cloud Support

The infrastructure code supports deployment to both AWS and Azure using the same codebase, allowing for cloud flexibility and disaster recovery options.

### Database High Availability

PostgreSQL is deployed with a primary-replica setup for data resilience, with automatic failover capabilities through repmgr.

### Automated SSL Certificates

Traefik automatically handles SSL certificate provisioning and renewal through Let's Encrypt.

### Simplified DevOps

Comprehensive scripts for deployment, updates, and maintenance tasks reduce operational complexity.

## Documentation

- [DEPLOYMENT.md](./DEPLOYMENT.md) - Detailed deployment instructions
- [CLI-REFERENCE.md](./CLI-REFERENCE.md) - Command-line reference guide

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the AGPL License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- André Sacilotto Santos - Lead Developer and Software Architect
- Agência Experimental de Engenharia de Software (AGES) - Project Scope and Stakeholders Management
- Hortti - Original Project Idea and Business Requirements
