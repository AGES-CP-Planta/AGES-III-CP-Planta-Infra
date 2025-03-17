module "security_rules" {
  source = "../modules/common/security-rules"
  environment_name = var.project_name
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