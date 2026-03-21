variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the ECS tasks"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security Group ID for the ECS tasks"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the ALB target group"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  type        = string
}

variable "db_host" {
  description = "Database Host"
  type        = string
}

variable "db_name" {
  description = "Database Name"
  type        = string
}

variable "db_master_secret_arn" {
  description = "ARN of the DB master secret"
  type        = string
}

variable "efs_file_system_id" {
  description = "ID of the EFS File System"
  type        = string
}

variable "efs_access_point_id" {
  description = "ID of the EFS Access Point"
  type        = string
}

variable "cpu" {
  description = "Task CPU limit"
  type        = number
  default     = 1024
}

variable "memory" {
  description = "Task Memory limit"
  type        = number
  default     = 2048
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}
