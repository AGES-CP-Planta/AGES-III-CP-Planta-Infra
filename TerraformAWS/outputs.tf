output "primary_region_instances" {
  description = "Public IPs of instances in the primary region"
  value       = local.primary_instance_ips
}

output "secondary_region_instances" {
  description = "Public IPs of instances in the secondary region"
  value       = local.secondary_instance_ips
}

output "vpc_peering_connection_id" {
  description = "ID of the VPC peering connection"
  value       = aws_vpc_peering_connection.primary_to_secondary.id
}