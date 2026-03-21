output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "cloudfront_domain_name" {
  value = module.cdn.cloudfront_domain_name
}

output "rds_endpoint" {
  value = module.database.db_endpoint
}

output "s3_media_bucket" {
  value = module.storage.s3_media_bucket_id
}
