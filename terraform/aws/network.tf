module "security_rules" {
  source = "../modules/common/security-rules"
  environment_name = var.project_name
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_subnet" "subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
  
  tags = {
    Name = "${var.project_name}-subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  
  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  
  tags = {
    Name = "${var.project_name}-rt"
  }
}

resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.rt.id
}

# Create Elastic IPs for instances
resource "aws_eip" "eip" {
  for_each = toset(var.instance_names)
  domain   = "vpc"
  
  tags = {
    Name = "${var.project_name}-eip-${each.key}"
  }
}

resource "aws_security_group" "sg" {
  name        = "${module.security_rules.environment_name}-sg"
  description = "Security group for CP Planta project"
  vpc_id      = aws_vpc.vpc.id

  # Dynamic block for TCP rules
  dynamic "ingress" {
    for_each = module.security_rules.common_tcp_ports
    content {
      description = "Allow ${ingress.key}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # Dynamic block for UDP rules
  dynamic "ingress" {
    for_each = module.security_rules.common_udp_ports
    content {
      description = "Allow ${ingress.key}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "udp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  
  # Outbound rule
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}