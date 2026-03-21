output "efs_file_system_id" {
  description = "ID of the EFS File System"
  value       = aws_efs_file_system.wp_content.id
}

output "efs_access_point_id" {
  description = "ID of the EFS Access Point"
  value       = aws_efs_access_point.wp_content.id
}

output "s3_media_bucket_id" {
  description = "ID of the S3 Media Bucket"
  value       = var.enable_s3_media ? aws_s3_bucket.wp_media[0].id : ""
}

output "s3_media_bucket_arn" {
  description = "ARN of the S3 Media Bucket"
  value       = var.enable_s3_media ? aws_s3_bucket.wp_media[0].arn : ""
}

output "s3_media_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 media bucket (useful for CloudFront)"
  value       = var.enable_s3_media ? aws_s3_bucket.wp_media[0].bucket_regional_domain_name : ""
}

output "s3_media_access_policy_arn" {
  description = "ARN of the IAM policy for S3 media access"
  value       = var.enable_s3_media ? aws_iam_policy.s3_media_access[0].arn : ""
}
