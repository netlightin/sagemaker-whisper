# General Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "loud-meadow"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "whisper-sagemaker"
    ManagedBy   = "Terraform"
    Environment = "production"
  }
}

# Networking Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "create_nat_gateway" {
  description = "Whether to create NAT gateways"
  type        = bool
  default     = true
}

# VPC Configuration - Existing VPC Support
variable "use_existing_vpc" {
  description = "Whether to use an existing VPC instead of creating a new one"
  type        = bool
  default     = false
}

variable "existing_vpc_id" {
  description = "ID of existing VPC to use (required if use_existing_vpc is true)"
  type        = string
  default     = null
}

variable "existing_public_subnet_ids" {
  description = "IDs of existing public subnets (required if use_existing_vpc is true)"
  type        = list(string)
  default     = []
}

variable "existing_private_subnet_ids" {
  description = "IDs of existing private subnets (required if use_existing_vpc is true)"
  type        = list(string)
  default     = []
}

variable "existing_internet_gateway_id" {
  description = "ID of existing Internet Gateway"
  type        = string
  default     = null
}

# ALB Configuration
variable "enable_deletion_protection" {
  description = "Whether to enable deletion protection for ALB"
  type        = bool
  default     = false
}

variable "enable_https" {
  description = "Whether to enable HTTPS"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ARN of ACM certificate for HTTPS"
  type        = string
  default     = null
}

variable "api_health_check_path" {
  description = "Health check path for API service"
  type        = string
  default     = "/health"
}

# SageMaker Configuration
variable "model_bucket_name" {
  description = "Name of S3 bucket containing model artifacts"
  type        = string
}

variable "model_data_url" {
  description = "S3 URL to model.tar.gz"
  type        = string
}

variable "sagemaker_instance_type" {
  description = "Instance type for SageMaker endpoint"
  type        = string
  default     = "ml.g4dn.xlarge"
}

variable "sagemaker_initial_instance_count" {
  description = "Initial instance count for SageMaker"
  type        = number
  default     = 1
}

variable "sagemaker_enable_autoscaling" {
  description = "Enable auto-scaling for SageMaker"
  type        = bool
  default     = true
}

variable "sagemaker_min_capacity" {
  description = "Minimum instances for SageMaker auto-scaling"
  type        = number
  default     = 1
}

variable "sagemaker_max_capacity" {
  description = "Maximum instances for SageMaker auto-scaling"
  type        = number
  default     = 3
}

variable "sagemaker_target_invocations" {
  description = "Target invocations per instance"
  type        = number
  default     = 1000
}

# API Service Configuration
variable "api_cpu" {
  description = "CPU units for API task"
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

variable "api_enable_autoscaling" {
  description = "Enable auto-scaling for API service"
  type        = bool
  default     = true
}

variable "api_min_capacity" {
  description = "Minimum API tasks for auto-scaling"
  type        = number
  default     = 1
}

variable "api_max_capacity" {
  description = "Maximum API tasks for auto-scaling"
  type        = number
  default     = 10
}

variable "api_cpu_target" {
  description = "Target CPU utilization for API auto-scaling"
  type        = number
  default     = 70
}

# S3 Batch Transcription Configuration
variable "transcription_bucket_name" {
  description = "S3 bucket name for batch transcription (leave empty to disable)"
  type        = string
  default     = ""
}

