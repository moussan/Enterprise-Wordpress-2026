variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the EFS mount targets will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs for EFS mount targets"
  type        = list(string)
}

variable "efs_security_group_ids" {
  description = "List of security group IDs for EFS"
  type        = list(string)
}

variable "enable_s3_media" {
  description = "Whether to create an S3 bucket for WP Offload Media"
  type        = bool
  default     = true
}
