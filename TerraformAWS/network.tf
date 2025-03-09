# TerraformAWS/network.tf

# Primary Region VPC
resource "aws_vpc" "primary_vpc" {
  provider             = aws.primary
  cidr_block           = var.vpc_cidr[var.primary_region]
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "${var.project_name}-primary-vpc"
  }
}

# Primary Region Subnet
resource "aws_subnet" "primary_subnet" {
  provider                = aws.primary
  vpc_id                  = aws_vpc.primary_vpc.id
  cidr_block              = var.subnet_cidr[var.primary_region]
  map_public_ip_on_launch = true
  availability_zone       = "${var.primary_region}a"
  
  tags = {
    Name = "${var.project_name}-primary-subnet"
  }
}

# Primary Region Internet Gateway
resource "aws_internet_gateway" "primary_igw" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary_vpc.id
  
  tags = {
    Name = "${var.project_name}-primary-igw"
  }
}

# Primary Region Route Table
resource "aws_route_table" "primary_rt" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.primary_igw.id
  }
  
  tags = {
    Name = "${var.project_name}-primary-rt"
  }
}

# Primary Region Route Table Association
resource "aws_route_table_association" "primary_rta" {
  provider       = aws.primary
  subnet_id      = aws_subnet.primary_subnet.id
  route_table_id = aws_route_table.primary_rt.id
}

# Primary Region Security Group
resource "aws_security_group" "primary_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-primary-sg"
  description = "Security group for CP Planta project in primary region"
  vpc_id      = aws_vpc.primary_vpc.id

  ingress {
    description = "Allow docker swarm manager"
    from_port   = 2377
    to_port     = 2377
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow docker swarm communication"
    from_port   = 7946
    to_port     = 7946
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow docker swarm overlay network"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow PostgreSQL"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow pgAdmin HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow pgAdmin HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow backend NodeJS"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow frontend NodeJS"
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rules
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-primary-sg"
  }
}

# Secondary Region VPC
resource "aws_vpc" "secondary_vpc" {
  provider             = aws.secondary
  cidr_block           = var.vpc_cidr[var.secondary_region]
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "${var.project_name}-secondary-vpc"
  }
}

# Secondary Region Subnet
resource "aws_subnet" "secondary_subnet" {
  provider                = aws.secondary
  vpc_id                  = aws_vpc.secondary_vpc.id
  cidr_block              = var.subnet_cidr[var.secondary_region]
  map_public_ip_on_launch = true
  availability_zone       = "${var.secondary_region}a"
  
  tags = {
    Name = "${var.project_name}-secondary-subnet"
  }
}

# Secondary Region Internet Gateway
resource "aws_internet_gateway" "secondary_igw" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary_vpc.id
  
  tags = {
    Name = "${var.project_name}-secondary-igw"
  }
}

# Secondary Region Route Table
resource "aws_route_table" "secondary_rt" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.secondary_igw.id
  }
  
  tags = {
    Name = "${var.project_name}-secondary-rt"
  }
}

# Secondary Region Route Table Association
resource "aws_route_table_association" "secondary_rta" {
  provider       = aws.secondary
  subnet_id      = aws_subnet.secondary_subnet.id
  route_table_id = aws_route_table.secondary_rt.id
}

# Secondary Region Security Group
resource "aws_security_group" "secondary_sg" {
  provider    = aws.secondary
  name        = "${var.project_name}-secondary-sg"
  description = "Security group for CP Planta project in secondary region"
  vpc_id      = aws_vpc.secondary_vpc.id

  ingress {
    description = "Allow docker swarm manager"
    from_port   = 2377
    to_port     = 2377
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow docker swarm communication"
    from_port   = 7946
    to_port     = 7946
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow docker swarm overlay network"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow PostgreSQL"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow pgAdmin HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow pgAdmin HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow backend NodeJS"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow frontend NodeJS"
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rules
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project_name}-secondary-sg"
  }
}

# VPC Peering between regions
resource "aws_vpc_peering_connection" "primary_to_secondary" {
  provider      = aws.primary
  vpc_id        = aws_vpc.primary_vpc.id
  peer_vpc_id   = aws_vpc.secondary_vpc.id
  peer_region   = var.secondary_region
  auto_accept   = false
  
  tags = {
    Name = "${var.project_name}-peering-primary-to-secondary"
  }
}

resource "aws_vpc_peering_connection_accepter" "secondary_accepter" {
  provider                  = aws.secondary
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id
  auto_accept               = true
  
  tags = {
    Name = "${var.project_name}-peering-accepter"
  }
}

# Add routes for VPC peering
resource "aws_route" "primary_to_secondary" {
  provider                  = aws.primary
  route_table_id            = aws_route_table.primary_rt.id
  destination_cidr_block    = var.vpc_cidr[var.secondary_region]
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id
}

resource "aws_route" "secondary_to_primary" {
  provider                  = aws.secondary
  route_table_id            = aws_route_table.secondary_rt.id
  destination_cidr_block    = var.vpc_cidr[var.primary_region]
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id
}