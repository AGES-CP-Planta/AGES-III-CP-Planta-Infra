locals {
  instance_public_ips = { for name, instance in aws_instance.instance : name => aws_eip.eip[name].public_ip }
}

locals {
  inventory_content = join("\n\n", [
    for name, ip in local.instance_public_ips : "[${name}]\n${ip} ansible_ssh_user=${var.username} ansible_ssh_private_key_file=./ssh_keys/${name}.pem"
  ])
}

resource "local_file" "ansible_inventory" {
  content  = local.inventory_content
  filename = "${path.module}/../static_ip.ini"
}

resource "tls_private_key" "instance_ssh_key" {
  for_each = toset(var.instance_names)
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create AWS key pairs
resource "aws_key_pair" "generated_key" {
  for_each   = toset(var.instance_names)
  key_name   = "${each.key}-key"
  public_key = tls_private_key.instance_ssh_key[each.key].public_key_openssh
}

# Save the private keys to files
resource "local_file" "ssh_key_files" {
  for_each        = tls_private_key.instance_ssh_key
  content         = each.value.private_key_pem
  filename        = "${path.module}/../ssh_keys/${each.key}.pem"
  file_permission = "0400"
}