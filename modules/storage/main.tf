data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# EFS for wp-content (Themes, Plugins, local uploads)
# -----------------------------------------------------------------------------

resource "aws_efs_file_system" "wp_content" {
  creation_token = "wp-efs-${var.environment}"
  encrypted      = true

  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name        = "wp-efs-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_efs_mount_target" "wp_content" {
  count           = length(var.subnet_ids)
  file_system_id  = aws_efs_file_system.wp_content.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = var.efs_security_group_ids
}

resource "aws_efs_access_point" "wp_content" {
  file_system_id = aws_efs_file_system.wp_content.id

  posix_user {
    gid = 33 # www-data
    uid = 33 # www-data
  }

  root_directory {
    path = "/wp-content"
    creation_info {
      owner_gid   = 33
      owner_uid   = 33
      permissions = "0755"
    }
  }

  tags = {
    Name        = "wp-efs-ap-${var.environment}"
    Environment = var.environment
  }
}

# -----------------------------------------------------------------------------
# S3 for Media Offloading (WP Offload Media or similar plugin)
# -----------------------------------------------------------------------------

resource "random_string" "s3_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "wp_media" {
  count  = var.enable_s3_media ? 1 : 0
  bucket = "wp-media-${var.environment}-${random_string.s3_suffix.result}"

  tags = {
    Name        = "wp-media-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_ownership_controls" "wp_media" {
  count  = var.enable_s3_media ? 1 : 0
  bucket = aws_s3_bucket.wp_media[0].id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "wp_media" {
  count  = var.enable_s3_media ? 1 : 0
  bucket = aws_s3_bucket.wp_media[0].id

  # If using CloudFront, block public access completely.
  # Otherwise, they might need to be public for direct access.
  # We assume CloudFront OAC will be used for Enterprise deployments.
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# IAM Policy for ECS Tasks to access S3 Media Bucket
# -----------------------------------------------------------------------------

resource "aws_iam_policy" "s3_media_access" {
  count       = var.enable_s3_media ? 1 : 0
  name        = "wp-s3-media-access-${var.environment}"
  description = "Allow ECS tasks to manage objects in the WP media S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:PutObjectAcl",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.wp_media[0].arn}/*"
      },
      {
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Effect   = "Allow"
        Resource = aws_s3_bucket.wp_media[0].arn
      }
    ]
  })
}
