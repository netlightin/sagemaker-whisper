# Networking Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.networking.alb_dns_name
}

output "alb_url" {
  description = "URL of the Application Load Balancer"
  value       = var.enable_https ? "https://${module.networking.alb_dns_name}" : "http://${module.networking.alb_dns_name}"
}

# ECR Outputs
output "ecr_api_repository_url" {
  description = "URL of the API ECR repository"
  value       = module.ecr_api.repository_url
}

output "ecr_frontend_repository_url" {
  description = "URL of the Frontend ECR repository"
  value       = module.ecr_frontend.repository_url
}

# SageMaker Outputs
output "sagemaker_endpoint_name" {
  description = "Name of the SageMaker endpoint"
  value       = module.sagemaker.endpoint_name
}

output "sagemaker_endpoint_arn" {
  description = "ARN of the SageMaker endpoint"
  value       = module.sagemaker.endpoint_arn
}

output "sagemaker_model_name" {
  description = "Name of the SageMaker model"
  value       = module.sagemaker.model_name
}

# ECS Outputs
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs.cluster_arn
}

output "api_service_name" {
  description = "Name of the API ECS service"
  value       = module.ecs.api_service_name
}

output "frontend_service_name" {
  description = "Name of the Frontend ECS service"
  value       = module.ecs.frontend_service_name
}

# CloudWatch Outputs
output "cloudwatch_dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "cloudwatch_log_group" {
  description = "Name of the ECS CloudWatch log group"
  value       = module.ecs.log_group_name
}

# Quick Reference
output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    application_url        = var.enable_https ? "https://${module.networking.alb_dns_name}" : "http://${module.networking.alb_dns_name}"
    sagemaker_endpoint     = module.sagemaker.endpoint_name
    ecs_cluster            = module.ecs.cluster_name
    cloudwatch_dashboard   = aws_cloudwatch_dashboard.main.dashboard_name
    region                 = var.aws_region
  }
}
