variable "environment" {
  description = "Name of the environment (dev, staging, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnets" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
}

variable "private_subnets" {
  description = "List of private subnet CIDR blocks (for ECS, etc.)"
  type        = list(string)
}

variable "isolated_subnets" {
  description = "List of isolated subnet CIDR blocks (for RDS, etc.)"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}
