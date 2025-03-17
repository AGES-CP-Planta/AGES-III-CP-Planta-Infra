variable "env_prefix" {
  description = "Environment prefix for naming"
  type        = string
  default     = "CP-Planta"
}

variable "domain_name" {
  description = "Base domain name for services"
  type        = string
  default     = "cpplanta.duckdns.org"
}

# Common service configurations
locals {
  services = {
    frontend = {
      subdomain    = "",
      port         = 3001,
      health_check = "/api/health"
    },
    backend = {
      subdomain    = "api",
      port         = 3000,
      health_check = "/api/health"
    },
    pgadmin = {
      subdomain    = "pgadmin",
      port         = 5050,
      health_check = "/"
    },
    visualizer = {
      subdomain    = "viz",
      port         = 8080,
      health_check = "/"
    },
    traefik = {
      subdomain    = "traefik",
      port         = 8080,
      health_check = "/ping"
    }
  }
}

output "services" {
  value = local.services
}

output "stack_prefix" {
  value = var.env_prefix
}

output "domain_name" {
  value = var.domain_name
}