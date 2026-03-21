variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

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
  description = "List of private subnet CIDR blocks"
  type        = list(string)
}

variable "isolated_subnets" {
  description = "List of isolated subnet CIDR blocks"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "enable_waf" {
  description = "Enable AWS WAF"
  type        = bool
  default     = true
}

variable "rds_instance_class" {
  description = "Instance class for RDS"
  type        = string
}

variable "rds_multi_az" {
  description = "Deploy RDS in Multi-AZ mode"
  type        = bool
}

variable "ecs_cpu" {
  description = "Task CPU limit"
  type        = number
}

variable "ecs_memory" {
  description = "Task Memory limit"
  type        = number
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
}

variable "certificate_arn" {
  description = "ARN of an existing ACM certificate for HTTPS"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Custom domain name for CloudFront"
  type        = string
  default     = ""
}

variable "enable_s3_media" {
  description = "Whether to deploy the S3 bucket for media offloading"
  type        = bool
  default     = true
}
