locals {
  vm_public_ips = { for name, vm in azurerm_linux_virtual_machine.vm : name => vm.public_ip_address }
}

locals {
  inventory_content = join("\n\n", [
    for name, ip in local.vm_public_ips : "[${name}]\n${ip} ansible_ssh_user=${var.username} ansible_ssh_private_key_file=./ssh_keys/${name}.pem"
  ])
}

resource "local_file" "ansible_inventory_tpl" {
  content  = local.inventory_content
  filename = "${path.module}/../static_ip.ini"
}

resource "tls_private_key" "vm_ssh_key" {
  for_each = toset(var.vm_names)
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Save the private keys to files
resource "local_file" "ssh_key_files" {
  for_each = tls_private_key.vm_ssh_key
  content  = each.value.private_key_pem
  filename = "${path.module}/../ssh_keys/${each.key}.pem"
  file_permission = "0400"
}