variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "image_tag_mutability" {
  description = "The tag mutability setting for the repository (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be either MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Indicates whether images are scanned after being pushed to the repository"
  type        = bool
  default     = true
}

variable "encryption_type" {
  description = "The encryption type to use for the repository (AES256 or KMS)"
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "KMS"], var.encryption_type)
    error_message = "encryption_type must be either AES256 or KMS."
  }
}

variable "kms_key_arn" {
  description = "The ARN of the KMS key to use when encryption_type is KMS"
  type        = string
  default     = null
}

variable "lifecycle_policy" {
  description = "Custom lifecycle policy for the repository (JSON string)"
  type        = string
  default     = null
}

variable "enable_default_lifecycle_policy" {
  description = "Whether to enable the default lifecycle policy"
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "Maximum number of images to keep (for default lifecycle policy)"
  type        = number
  default     = 30
}

variable "untagged_image_days" {
  description = "Number of days to keep untagged images (for default lifecycle policy)"
  type        = number
  default     = 7
}

variable "repository_policy" {
  description = "Custom repository policy (JSON string)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to the repository"
  type        = map(string)
  default     = {}
}
