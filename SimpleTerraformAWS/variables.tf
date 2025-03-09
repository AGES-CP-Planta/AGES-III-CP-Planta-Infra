variable "project_name" {
  default = "cp-planta-ages"
}

variable "region" {
  default = "us-east-2"
}

variable "vpc_name" {
  default = "cp-planta-vpc"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "subnet_name" {
  type    = string
  default = "cp-planta-subnet"
}

variable "subnet_cidr" {
  default = "10.0.1.0/24"
}

variable "public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

variable "instance_names" {
  default = ["instance1", "instance2"]
}

variable "username" {
  default = "adminuser"
}

variable "instance_type" {
  default = "t2.small"  
}