variable "project_name" {
  description = "Name of the project, used for resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "enable_container_insights" {
  description = "Whether to enable CloudWatch Container Insights"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

# SageMaker Configuration
variable "sagemaker_endpoint_name" {
  description = "Name of the SageMaker endpoint"
  type        = string
}

variable "sagemaker_endpoint_arn" {
  description = "ARN of the SageMaker endpoint"
  type        = string
}

# Network Configuration
variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "ecs_security_group_ids" {
  description = "List of security group IDs for ECS tasks"
  type        = list(string)
}

# ALB Configuration
variable "alb_listener_arn" {
  description = "ARN of the ALB listener (for dependency)"
  type        = string
}

variable "api_target_group_arn" {
  description = "ARN of the target group for API service"
  type        = string
}

variable "frontend_target_group_arn" {
  description = "ARN of the target group for frontend service"
  type        = string
}

# API Service Configuration
variable "api_image_uri" {
  description = "Docker image URI for API service"
  type        = string
}

variable "api_cpu" {
  description = "CPU units for API task (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "512"
}

variable "api_memory" {
  description = "Memory (MB) for API task"
  type        = string
  default     = "1024"
}

variable "api_container_port" {
  description = "Container port for API service"
  type        = number
  default     = 8080
}

variable "api_desired_count" {
  description = "Desired number of API tasks"
  type        = number
  default     = 2
}

variable "api_environment" {
  description = "Environment variables for API service"
  type        = map(string)
  default     = {}
}

variable "api_health_check" {
  description = "Health check configuration for API container"
  type = object({
    command     = list(string)
    interval    = number
    timeout     = number
    retries     = number
    startPeriod = number
  })
  default = {
    command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
    interval    = 30
    timeout     = 5
    retries     = 3
    startPeriod = 60
  }
}

variable "api_url" {
  description = "URL of the API service (for frontend)"
  type        = string
  default     = ""
}

# Frontend Service Configuration
variable "frontend_image_uri" {
  description = "Docker image URI for frontend service"
  type        = string
}

variable "frontend_cpu" {
  description = "CPU units for frontend task (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "256"
}

variable "frontend_memory" {
  description = "Memory (MB) for frontend task"
  type        = string
  default     = "512"
}

variable "frontend_container_port" {
  description = "Container port for frontend service"
  type        = number
  default     = 3000
}

variable "frontend_desired_count" {
  description = "Desired number of frontend tasks"
  type        = number
  default     = 2
}

variable "frontend_environment" {
  description = "Environment variables for frontend service"
  type        = map(string)
  default     = {}
}

variable "frontend_health_check" {
  description = "Health check configuration for frontend container"
  type = object({
    command     = list(string)
    interval    = number
    timeout     = number
    retries     = number
    startPeriod = number
  })
  default = {
    command     = ["CMD-SHELL", "curl -f http://localhost:3000 || exit 1"]
    interval    = 30
    timeout     = 5
    retries     = 3
    startPeriod = 60
  }
}

# Auto Scaling Configuration - API
variable "enable_api_autoscaling" {
  description = "Whether to enable auto-scaling for API service"
  type        = bool
  default     = true
}

variable "api_min_capacity" {
  description = "Minimum number of API tasks for auto-scaling"
  type        = number
  default     = 1
}

variable "api_max_capacity" {
  description = "Maximum number of API tasks for auto-scaling"
  type        = number
  default     = 10
}

variable "api_cpu_target" {
  description = "Target CPU utilization percentage for API auto-scaling"
  type        = number
  default     = 70
}

# Auto Scaling Configuration - Frontend
variable "enable_frontend_autoscaling" {
  description = "Whether to enable auto-scaling for frontend service"
  type        = bool
  default     = true
}

variable "frontend_min_capacity" {
  description = "Minimum number of frontend tasks for auto-scaling"
  type        = number
  default     = 1
}

variable "frontend_max_capacity" {
  description = "Maximum number of frontend tasks for auto-scaling"
  type        = number
  default     = 10
}

variable "frontend_cpu_target" {
  description = "Target CPU utilization percentage for frontend auto-scaling"
  type        = number
  default     = 70
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
