variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security Group ID for the ALB"
  type        = string
}

variable "enable_waf" {
  description = "Whether to integrate WAF"
  type        = bool
  default     = true
}

variable "certificate_arn" {
  description = "ARN of an existing ACM certificate for HTTPS (optional for dev)"
  type        = string
  default     = ""
}
