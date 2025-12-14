variable "project_name" {
  description = "Name of the project, used for resource naming"
  type        = string
}

variable "model_bucket_name" {
  description = "Name of the S3 bucket containing model artifacts"
  type        = string
}

variable "model_data_url" {
  description = "S3 URL to the model.tar.gz file"
  type        = string
}

variable "inference_image_uri" {
  description = "URI of the Docker image for SageMaker inference"
  type        = string
}

variable "instance_type" {
  description = "Instance type for SageMaker endpoint"
  type        = string
  default     = "ml.g4dn.xlarge"

  validation {
    condition     = can(regex("^ml\\.", var.instance_type))
    error_message = "instance_type must be a valid SageMaker instance type (e.g., ml.g4dn.xlarge, ml.g5.xlarge)."
  }
}

variable "initial_instance_count" {
  description = "Initial number of instances for the endpoint"
  type        = number
  default     = 1

  validation {
    condition     = var.initial_instance_count > 0
    error_message = "initial_instance_count must be greater than 0."
  }
}

variable "model_environment" {
  description = "Environment variables for the model container"
  type        = map(string)
  default     = {}
}

variable "subnet_ids" {
  description = "List of subnet IDs for VPC configuration"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for VPC configuration"
  type        = list(string)
}

variable "enable_autoscaling" {
  description = "Whether to enable auto-scaling for the endpoint"
  type        = bool
  default     = true
}

variable "min_capacity" {
  description = "Minimum number of instances for auto-scaling"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of instances for auto-scaling"
  type        = number
  default     = 3
}

variable "target_invocations_per_instance" {
  description = "Target number of invocations per instance for auto-scaling"
  type        = number
  default     = 1000
}

variable "scale_in_cooldown" {
  description = "Cooldown period (in seconds) before scaling in"
  type        = number
  default     = 300
}

variable "scale_out_cooldown" {
  description = "Cooldown period (in seconds) before scaling out"
  type        = number
  default     = 60
}

variable "error_threshold" {
  description = "Threshold for model invocation errors alarm"
  type        = number
  default     = 5
}

variable "latency_threshold" {
  description = "Threshold for model latency alarm (in milliseconds)"
  type        = number
  default     = 30000
}

variable "enable_low_invocation_alarm" {
  description = "Whether to enable low invocation alarm"
  type        = bool
  default     = false
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarms trigger (e.g., SNS topics)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
