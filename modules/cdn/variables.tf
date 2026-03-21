variable "environment" {
  description = "Environment name"
  type        = string
}

variable "alb_dns_name" {
  description = "The DNS name of the ALB serving as the origin"
  type        = string
}

variable "domain_name" {
  description = "Custom domain name (optional)"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for CloudFront (us-east-1)"
  type        = string
  default     = ""
}
