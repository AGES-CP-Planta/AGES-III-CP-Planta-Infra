variable "project_name" {
  default = "cp-planta-ages"
}
variable "primary_region" {
  description = "Primary AWS region"
  default     = "us-east-2"
}

variable "secondary_region" {
  description = "Secondary AWS region for disaster recovery"
  default     = "us-west-2"
}

variable "vpc_name" {
  default = "cp-planta-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for VPCs (will be different in each region)"
  type        = map(string)
  default     = {
    "us-east-2" = "10.0.0.0/16"
    "us-west-2" = "10.1.0.0/16"
  }
}

variable "subnet_name" {
  type    = string
  default = "cp-planta-subnet"
}

variable "subnet_cidr" {
  description = "CIDR block for subnets (will be different in each region)"
  type        = map(string)
  default     = {
    "us-east-2" = "10.0.1.0/24"
    "us-west-2" = "10.1.1.0/24"
  }
}

variable "public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

variable "instance_names" {
  description = "Names for instances in each region"
  type        = map(list(string))
  default     = {
    "us-east-2" = ["primary-manager", "primary-worker"]
    "us-west-2" = ["dr-manager", "dr-worker"]
  }
}

variable "instance_type" {
  default = "t2.small"  
}

variable "username" {
  default = "ubuntu"
}
