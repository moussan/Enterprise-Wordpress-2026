module "networking" {
  source             = "../modules/networking"
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  isolated_subnets   = var.isolated_subnets
  availability_zones = var.availability_zones
}

module "security" {
  source      = "../modules/security"
  environment = var.environment
  vpc_id      = module.networking.vpc_id
  enable_waf  = var.enable_waf
  alb_arn     = module.alb.alb_arn
}

module "database" {
  source                 = "../modules/database"
  environment            = var.environment
  subnet_ids             = module.networking.isolated_subnet_ids
  vpc_security_group_ids = [module.security.rds_sg_id]
  instance_class         = var.rds_instance_class
  multi_az               = var.rds_multi_az
}

module "storage" {
  source                 = "../modules/storage"
  environment            = var.environment
  vpc_id                 = module.networking.vpc_id
  subnet_ids             = module.networking.private_subnet_ids
  efs_security_group_ids = [module.security.efs_sg_id]
  enable_s3_media        = var.enable_s3_media
}

module "alb" {
  source                = "../modules/alb"
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.security.alb_sg_id
  enable_waf            = var.enable_waf
  certificate_arn       = var.certificate_arn
}

module "compute" {
  source                      = "../modules/compute"
  environment                 = var.environment
  vpc_id                      = module.networking.vpc_id
  private_subnet_ids          = module.networking.private_subnet_ids
  ecs_security_group_id       = module.security.ecs_tasks_sg_id
  target_group_arn            = module.alb.target_group_arn
  ecs_task_execution_role_arn = module.security.ecs_task_execution_role_arn
  ecs_task_role_arn           = module.security.ecs_task_role_arn
  efs_file_system_id          = module.storage.efs_file_system_id
  efs_access_point_id         = module.storage.efs_access_point_id
  cpu                         = var.ecs_cpu
  memory                      = var.ecs_memory
  desired_count               = var.ecs_desired_count
  db_host                     = module.database.db_endpoint
  db_name                     = module.database.db_name
  db_master_secret_arn        = module.database.db_master_secret_arn
}

module "cdn" {
  source          = "../modules/cdn"
  environment     = var.environment
  alb_dns_name    = module.alb.alb_dns_name
  domain_name     = var.domain_name
  certificate_arn = var.certificate_arn
}
