terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

# Networking Module
module "networking" {
  source = "./modules/networking"

  project_name = var.project_name
  aws_region   = var.aws_region

  # VPC Configuration - Existing VPC Support
  use_existing_vpc             = var.use_existing_vpc
  existing_vpc_id              = var.existing_vpc_id
  existing_public_subnet_ids   = var.existing_public_subnet_ids
  existing_private_subnet_ids  = var.existing_private_subnet_ids
  existing_internet_gateway_id = var.existing_internet_gateway_id

  # Fallback for new VPC mode
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  create_nat_gateway   = var.use_existing_vpc ? false : var.create_nat_gateway

  # ALB Configuration
  enable_deletion_protection = var.enable_deletion_protection
  enable_https               = var.enable_https
  certificate_arn            = var.certificate_arn
  api_port                   = var.api_container_port
  api_health_check_path      = var.api_health_check_path

  tags = var.common_tags
}

# ECR Repositories
module "ecr_api" {
  source = "./modules/ecr"

  repository_name                 = "${var.project_name}-api"
  image_tag_mutability            = "MUTABLE"
  scan_on_push                    = true
  enable_default_lifecycle_policy = true
  max_image_count                 = 30
  untagged_image_days             = 7

  tags = var.common_tags
}

module "ecr_inference" {
  source = "./modules/ecr"

  repository_name                 = "${var.project_name}-inference"
  image_tag_mutability            = "MUTABLE"
  scan_on_push                    = true
  enable_default_lifecycle_policy = true
  max_image_count                 = 30
  untagged_image_days             = 7

  tags = var.common_tags
}

# SageMaker Module
module "sagemaker" {
  source = "./modules/sagemaker"

  project_name      = var.project_name
  model_bucket_name = var.model_bucket_name
  model_data_url    = var.model_data_url
  # Using custom Docker container with fixed numpy dependencies
  # Note: Using :latest tag for inference image
  inference_image_uri    = "654654436000.dkr.ecr.${var.aws_region}.amazonaws.com/loud-meadow-inference:latest"
  instance_type          = var.sagemaker_instance_type
  initial_instance_count = var.sagemaker_initial_instance_count

  subnet_ids         = module.networking.private_subnet_ids
  security_group_ids = [module.networking.sagemaker_security_group_id]

  # Auto-scaling
  enable_autoscaling              = var.sagemaker_enable_autoscaling
  min_capacity                    = var.sagemaker_min_capacity
  max_capacity                    = var.sagemaker_max_capacity
  target_invocations_per_instance = var.sagemaker_target_invocations

  # Alarms
  error_threshold   = 5
  latency_threshold = 30000

  tags = var.common_tags

  depends_on = [module.networking]
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"

  project_name   = var.project_name
  aws_region     = var.aws_region
  container_image = "${module.ecr_api.repository_url}:latest"

  # Task Configuration
  task_cpu       = var.api_cpu
  task_memory    = var.api_memory
  desired_count  = var.api_desired_count
  max_capacity   = var.api_max_capacity
  log_retention_days = 7

  # SageMaker Configuration
  sagemaker_endpoint_name = module.sagemaker.endpoint_name
  sagemaker_endpoint_arn  = module.sagemaker.endpoint_arn

  # Network Configuration
  private_subnet_ids     = module.networking.private_subnet_ids
  ecs_security_group_ids = [module.networking.ecs_security_group_id]

  # ALB Configuration
  alb_listener_arn = module.networking.http_listener_arn
  target_group_arn = module.networking.api_target_group_arn

  depends_on = [module.sagemaker, module.networking]
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/SageMaker", "ModelLatency", { stat = "Average", label = "Avg Latency" }],
            ["...", { stat = "Maximum", label = "Max Latency" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "SageMaker Model Latency"
          yAxis = {
            left = {
              label = "Milliseconds"
            }
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/SageMaker", "Invocations", { stat = "Sum", label = "Total Invocations" }],
            [".", "ModelInvocationErrors", { stat = "Sum", label = "Errors" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "SageMaker Invocations"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", module.ecs.service_name, "ClusterName", module.ecs.cluster_name, { stat = "Average", label = "CPU" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS CPU Utilization"
          yAxis = {
            left = {
              label = "Percent"
            }
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", module.networking.alb_arn, { stat = "Average", label = "Response Time" }],
            [".", "RequestCount", ".", ".", { stat = "Sum", label = "Request Count" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ALB Metrics"
        }
      }
    ]
  })
}
