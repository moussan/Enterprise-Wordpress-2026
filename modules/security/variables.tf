variable "environment" {
  description = "Name of the environment (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the security groups will be created"
  type        = string
}

variable "enable_waf" {
  description = "Whether to enable AWS WAF on the ALB"
  type        = bool
  default     = true
}

variable "alb_arn" {
  description = "ARN of the ALB (required if enable_waf is true)"
  type        = string
  default     = ""
}
