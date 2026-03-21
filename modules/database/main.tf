resource "aws_db_subnet_group" "main" {
  name       = "wp-db-subnet-group-${var.environment}"
  subnet_ids = var.subnet_ids

  tags = {
    Name        = "wp-db-subnet-group-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_db_parameter_group" "main" {
  name   = "wp-db-pg-${var.environment}"
  family = "mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }
}

resource "aws_db_instance" "main" {
  identifier = "wp-rds-${var.environment}"

  engine                = "mysql"
  engine_version        = "8.0"
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = 100

  db_name  = var.db_name
  username = var.db_username

  # Leverage Secrets Manager integration for Master Password (AWS handles rotation)
  manage_master_user_password = true

  vpc_security_group_ids = var.vpc_security_group_ids
  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.main.name

  multi_az            = var.multi_az
  publicly_accessible = false
  storage_encrypted   = true

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Sun:04:00-Sun:05:00"

  skip_final_snapshot       = var.environment == "prod" ? false : true
  final_snapshot_identifier = "wp-rds-final-${var.environment}"

  tags = {
    Name        = "wp-rds-${var.environment}"
    Environment = var.environment
  }
}
