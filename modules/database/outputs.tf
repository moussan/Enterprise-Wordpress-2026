output "db_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = aws_db_instance.main.endpoint
}

output "db_name" {
  description = "The name of the database"
  value       = aws_db_instance.main.db_name
}

output "db_master_secret_arn" {
  description = "ARN of the master user secret created in Secrets Manager"
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}
