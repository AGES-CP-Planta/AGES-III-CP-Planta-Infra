locals {
  # Collect IPs from primary region
  primary_instance_ips = {
    for name in var.instance_names[var.primary_region] : 
    name => aws_eip.primary_eip[name].public_ip
  }
  
  # Collect IPs from secondary region
  secondary_instance_ips = {
    for name in var.instance_names[var.secondary_region] : 
    name => aws_eip.secondary_eip[name].public_ip
  }
  
  # Combine for the complete inventory
  all_instance_ips = merge(local.primary_instance_ips, local.secondary_instance_ips)
  
  # Generate inventory file content with regional groups
  inventory_content = join("\n\n", [
    # Primary region group
    "[primary_region]\n${join("\n", [
      for name, ip in local.primary_instance_ips : 
      "${ip} ansible_ssh_user=${var.username} ansible_ssh_private_key_file=../ssh_keys/${name}.pem"
    ])}",
    
    # Secondary region group
    "[secondary_region]\n${join("\n", [
      for name, ip in local.secondary_instance_ips : 
      "${ip} ansible_ssh_user=${var.username} ansible_ssh_private_key_file=../ssh_keys/${name}.pem"
    ])}",
    
    # Manager nodes group
    "[manager_nodes]\n${join("\n", [
      for name, ip in local.all_instance_ips : 
      "${ip} ansible_ssh_user=${var.username} ansible_ssh_private_key_file=../ssh_keys/${name}.pem"
      if strcontains(name, "manager")
    ])}",
    
    # Worker nodes group 
    "[worker_nodes]\n${join("\n", [
      for name, ip in local.all_instance_ips : 
      "${ip} ansible_ssh_user=${var.username} ansible_ssh_private_key_file=../ssh_keys/${name}.pem"
      if strcontains(name, "worker")
    ])}"
  ])
}

# Generate Ansible inventory file
resource "local_file" "ansible_inventory" {
  content  = local.inventory_content
  filename = "${path.module}/../multi_region_inventory.ini"
}

# Save SSH private keys
resource "local_file" "primary_ssh_key_files" {
  for_each        = tls_private_key.primary_ssh_key
  content         = each.value.private_key_pem
  filename        = "${path.module}/../ssh_keys/${each.key}.pem"
  file_permission = "0400"
}

resource "local_file" "secondary_ssh_key_files" {
  for_each        = tls_private_key.secondary_ssh_key
  content         = each.value.private_key_pem
  filename        = "${path.module}/../ssh_keys/${each.key}.pem"
  file_permission = "0400"
}