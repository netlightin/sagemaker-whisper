output "execution_role_arn" {
  description = "ARN of the SageMaker execution IAM role"
  value       = aws_iam_role.sagemaker_execution.arn
}

output "execution_role_name" {
  description = "Name of the SageMaker execution IAM role"
  value       = aws_iam_role.sagemaker_execution.name
}

output "model_name" {
  description = "Name of the SageMaker model"
  value       = aws_sagemaker_model.whisper.name
}

output "model_arn" {
  description = "ARN of the SageMaker model"
  value       = aws_sagemaker_model.whisper.arn
}

output "endpoint_config_name" {
  description = "Name of the SageMaker endpoint configuration"
  value       = aws_sagemaker_endpoint_configuration.whisper.name
}

output "endpoint_config_arn" {
  description = "ARN of the SageMaker endpoint configuration"
  value       = aws_sagemaker_endpoint_configuration.whisper.arn
}

output "endpoint_name" {
  description = "Name of the SageMaker endpoint"
  value       = aws_sagemaker_endpoint.whisper.name
}

output "endpoint_arn" {
  description = "ARN of the SageMaker endpoint"
  value       = aws_sagemaker_endpoint.whisper.arn
}

output "invocation_error_alarm_arn" {
  description = "ARN of the invocation error CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.model_invocation_errors.arn
}

output "latency_alarm_arn" {
  description = "ARN of the latency CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.model_latency.arn
}

output "autoscaling_target_id" {
  description = "ID of the auto-scaling target (if enabled)"
  value       = var.enable_autoscaling ? aws_appautoscaling_target.sagemaker_target[0].id : null
}

output "autoscaling_policy_arn" {
  description = "ARN of the auto-scaling policy (if enabled)"
  value       = var.enable_autoscaling ? aws_appautoscaling_policy.sagemaker_policy[0].arn : null
}
