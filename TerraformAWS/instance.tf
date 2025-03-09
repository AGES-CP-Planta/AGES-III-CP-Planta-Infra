# Get latest Ubuntu AMI for each region
data "aws_ami" "primary_ubuntu" {
  provider    = aws.primary
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "secondary_ubuntu" {
  provider    = aws.secondary
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# SSH Keys for Primary Region
resource "tls_private_key" "primary_ssh_key" {
  for_each  = toset(var.instance_names[var.primary_region])
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "primary_key_pair" {
  for_each   = toset(var.instance_names[var.primary_region])
  provider   = aws.primary
  key_name   = "${each.key}-key"
  public_key = tls_private_key.primary_ssh_key[each.key].public_key_openssh
}

# SSH Keys for Secondary Region
resource "tls_private_key" "secondary_ssh_key" {
  for_each  = toset(var.instance_names[var.secondary_region])
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "secondary_key_pair" {
  for_each   = toset(var.instance_names[var.secondary_region])
  provider   = aws.secondary
  key_name   = "${each.key}-key"
  public_key = tls_private_key.secondary_ssh_key[each.key].public_key_openssh
}

# Elastic IPs for Primary Region
resource "aws_eip" "primary_eip" {
  for_each = toset(var.instance_names[var.primary_region])
  provider = aws.primary
  domain   = "vpc"
  
  tags = {
    Name = "${var.project_name}-eip-${each.key}"
  }
}

# Elastic IPs for Secondary Region
resource "aws_eip" "secondary_eip" {
  for_each = toset(var.instance_names[var.secondary_region])
  provider = aws.secondary
  domain   = "vpc"
  
  tags = {
    Name = "${var.project_name}-eip-${each.key}"
  }
}

# EC2 Instances in Primary Region
resource "aws_instance" "primary_instance" {
  for_each      = toset(var.instance_names[var.primary_region])
  provider      = aws.primary
  ami           = data.aws_ami.primary_ubuntu.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.primary_subnet.id
  
  key_name               = aws_key_pair.primary_key_pair[each.key].key_name
  vpc_security_group_ids = [aws_security_group.primary_sg.id]
  
  root_block_device {
    volume_size = 64
    volume_type = "gp2"
  }
  
  tags = {
    Name   = each.key
    Region = var.primary_region
    Role   = strcontains(each.key, "manager") ? "manager" : "worker"
  }
}

# EC2 Instances in Secondary Region
resource "aws_instance" "secondary_instance" {
  for_each      = toset(var.instance_names[var.secondary_region])
  provider      = aws.secondary
  ami           = data.aws_ami.secondary_ubuntu.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.secondary_subnet.id
  
  key_name               = aws_key_pair.secondary_key_pair[each.key].key_name
  vpc_security_group_ids = [aws_security_group.secondary_sg.id]
  
  root_block_device {
    volume_size = 64
    volume_type = "gp2"
  }
  
  tags = {
    Name   = each.key
    Region = var.secondary_region
    Role   = strcontains(each.key, "manager") ? "manager" : "worker"
  }
}

# Associate Elastic IPs with primary instances
resource "aws_eip_association" "primary_eip_assoc" {
  for_each       = toset(var.instance_names[var.primary_region])
  provider       = aws.primary
  instance_id    = aws_instance.primary_instance[each.key].id
  allocation_id  = aws_eip.primary_eip[each.key].id
}

# Associate Elastic IPs with secondary instances
resource "aws_eip_association" "secondary_eip_assoc" {
  for_each       = toset(var.instance_names[var.secondary_region])
  provider       = aws.secondary
  instance_id    = aws_instance.secondary_instance[each.key].id
  allocation_id  = aws_eip.secondary_eip[each.key].id
}