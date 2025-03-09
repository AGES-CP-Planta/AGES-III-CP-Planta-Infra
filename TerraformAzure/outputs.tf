# Adjust the output to use the dynamically generated map
output "vm_public_ips" {
  value = local.vm_public_ips
}

output "vm_ssh_private_keys" {
  value = { for k, v in tls_private_key.vm_ssh_key : k => v.private_key_pem }
  sensitive = true
}