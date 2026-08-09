variable "project_name" {
  description = "Project name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "container_image" {
  description = "Docker image URI for the application (from ECR)"
  type        = string
}

variable "task_cpu" {
  description = "Task CPU units (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Task memory in MB"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum number of ECS tasks for autoscaling"
  type        = number
  default     = 4
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
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

variable "target_group_arn" {
  description = "ARN of the target group for ECS service"
  type        = string
}
