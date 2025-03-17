variable "environment_name" {
  description = "Environment name for naming resources"
  type        = string
  default     = "cp-planta"
}

# Common service ports used in both AWS and Azure
locals {
  common_tcp_ports = {
    ssh                = 22,
    http               = 80,
    https              = 443,
    postgres           = 5432,
    postgres_replica   = 5433,
    pgbouncer          = 6432,
    backend_nodejs     = 3000,
    frontend_nodejs    = 3001,
    docker_swarm_mgmt  = 2377,
    docker_swarm_comm  = 7946,
    visualizer         = 8080,
    dns_tcp            = 53
  }
  
  common_udp_ports = {
    docker_swarm_overlay = 4789,
    dns_udp              = 53
  }
}

locals {
  # Generate numbered tcp rules starting at priority 100
  tcp_rules_with_priority = {
    for i, name in keys(local.common_tcp_ports) : name => {
      port = local.common_tcp_ports[name]
      priority = 100 + i
      name = name  
    }
  }
  
  # Same for UDP starting at priority 300
  udp_rules_with_priority = {
    for i, name in keys(local.common_udp_ports) : name => {
      port = local.common_udp_ports[name]
      priority = 300 + i
      name = name  
    }
  }
}

output "common_tcp_ports" {
  value = local.common_tcp_ports
}

output "common_udp_ports" {
  value = local.common_udp_ports
}


output "tcp_rules_with_priority" {
  value = local.tcp_rules_with_priority
}

output "udp_rules_with_priority" {
  value = local.udp_rules_with_priority
}

output "environment_name" {
  value = var.environment_name
}