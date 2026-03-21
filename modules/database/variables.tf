variable "environment" {
  description = "Environment name"
  type        = string
}

variable "subnet_ids" {
  description = "List of isolated subnet IDs for the RDS instance"
  type        = list(string)
}

variable "vpc_security_group_ids" {
  description = "List of security group IDs for RDS"
  type        = list(string)
}

variable "instance_class" {
  description = "Instance class for RDS"
  type        = string
  default     = "db.t3.medium"
}

variable "allocated_storage" {
  description = "Allocated storage size in GB"
  type        = number
  default     = 20
}

variable "multi_az" {
  description = "Whether to deploy Multi-AZ RDS"
  type        = bool
  default     = true
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "wordpress"
}

variable "db_username" {
  description = "Master username for database"
  type        = string
  default     = "admin"
}
