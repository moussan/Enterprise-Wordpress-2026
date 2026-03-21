data "aws_region" "current" {}

resource "aws_ecs_cluster" "main" {
  name = "wp-cluster-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "wp-cluster-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "wp" {
  name              = "/ecs/wp-${var.environment}"
  retention_in_days = 30

  tags = {
    Name        = "wp-log-group-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_ecs_task_definition" "wp" {
  family                   = "wp-task-${var.environment}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  volume {
    name = "wp-content"
    efs_volume_configuration {
      file_system_id     = var.efs_file_system_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = var.efs_access_point_id
        iam             = "ENABLED" # Requires task IAM role policy
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "wordpress"
      image     = "wordpress:php8.2-apache"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      environment = [
        {
          name  = "WORDPRESS_DB_HOST"
          value = var.db_host
        },
        {
          name  = "WORDPRESS_DB_NAME"
          value = var.db_name
        },
        {
          name  = "WORDPRESS_DB_USER"
          value = "admin" # hardcoding matching var.db_username from db module
        }
      ]
      secrets = [
        {
          name      = "WORDPRESS_DB_PASSWORD"
          valueFrom = "${var.db_master_secret_arn}:password::"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "wp-content"
          containerPath = "/var/www/html/wp-content"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.wp.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Environment = var.environment
  }
}

resource "aws_ecs_service" "wp" {
  name            = "wp-service-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.wp.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [var.ecs_security_group_id]
    subnets          = var.private_subnet_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "wordpress"
    container_port   = 80
  }

  tags = {
    Environment = var.environment
  }
}

# Auto Scaling (Target Tracking)
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = var.environment == "prod" ? 10 : 2
  min_capacity       = var.environment == "prod" ? 2 : 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.wp.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  name               = "wp-cpu-autoscaling-${var.environment}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 60.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
