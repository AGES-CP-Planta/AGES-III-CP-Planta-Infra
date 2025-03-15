# Output the public IPs of the instances
output "instance_public_ips" {
  value = local.instance_public_ips
}

# Output the SSH private keys (marked as sensitive)
output "instance_ssh_private_keys" {
  value     = { for k, v in tls_private_key.instance_ssh_key : k => v.private_key_pem }
  sensitive = true
}