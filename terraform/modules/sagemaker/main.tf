# IAM Role for SageMaker Execution
resource "aws_iam_role" "sagemaker_execution" {
  name               = "${var.project_name}-sagemaker-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-sagemaker-execution-role"
    }
  )
}

# Attach AWS Managed Policy for SageMaker
resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  role       = aws_iam_role.sagemaker_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# Custom Policy for S3 Access to Model Artifacts
resource "aws_iam_role_policy" "sagemaker_s3_access" {
  name = "${var.project_name}-sagemaker-s3-policy"
  role = aws_iam_role.sagemaker_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.model_bucket_name}",
          "arn:aws:s3:::${var.model_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# SageMaker Model
resource "aws_sagemaker_model" "whisper" {
  name               = "${var.project_name}-whisper-model"
  execution_role_arn = aws_iam_role.sagemaker_execution.arn

  primary_container {
    image          = var.inference_image_uri
    model_data_url = var.model_data_url
    environment    = var.model_environment
  }

  vpc_config {
    subnets            = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-whisper-model"
    }
  )
}

# SageMaker Endpoint Configuration
resource "aws_sagemaker_endpoint_configuration" "whisper" {
  name = "${var.project_name}-whisper-endpoint-config"

  production_variants {
    variant_name           = "AllTraffic"
    model_name             = aws_sagemaker_model.whisper.name
    instance_type          = var.instance_type
    initial_instance_count = var.initial_instance_count
    initial_variant_weight = 1
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-whisper-endpoint-config"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# SageMaker Endpoint
resource "aws_sagemaker_endpoint" "whisper" {
  name                 = "${var.project_name}-whisper-endpoint"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.whisper.name

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-whisper-endpoint"
    }
  )
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "sagemaker_target" {
  count              = var.enable_autoscaling ? 1 : 0
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "endpoint/${aws_sagemaker_endpoint.whisper.name}/variant/AllTraffic"
  scalable_dimension = "sagemaker:variant:DesiredInstanceCount"
  service_namespace  = "sagemaker"
}

# Auto Scaling Policy - Target Tracking
resource "aws_appautoscaling_policy" "sagemaker_policy" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${var.project_name}-sagemaker-autoscaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.sagemaker_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.sagemaker_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.sagemaker_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "SageMakerVariantInvocationsPerInstance"
    }
    target_value       = var.target_invocations_per_instance
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown
  }
}

# CloudWatch Alarm - Model Invocation Errors
resource "aws_cloudwatch_metric_alarm" "model_invocation_errors" {
  alarm_name          = "${var.project_name}-sagemaker-invocation-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ModelInvocationErrors"
  namespace           = "AWS/SageMaker"
  period              = 60
  statistic           = "Sum"
  threshold           = var.error_threshold
  alarm_description   = "This metric monitors SageMaker model invocation errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    EndpointName = aws_sagemaker_endpoint.whisper.name
    VariantName  = "AllTraffic"
  }

  alarm_actions = var.alarm_actions

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-sagemaker-invocation-errors"
    }
  )
}

# CloudWatch Alarm - Model Latency
resource "aws_cloudwatch_metric_alarm" "model_latency" {
  alarm_name          = "${var.project_name}-sagemaker-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ModelLatency"
  namespace           = "AWS/SageMaker"
  period              = 60
  statistic           = "Average"
  threshold           = var.latency_threshold
  alarm_description   = "This metric monitors SageMaker model latency"
  treat_missing_data  = "notBreaching"

  dimensions = {
    EndpointName = aws_sagemaker_endpoint.whisper.name
    VariantName  = "AllTraffic"
  }

  alarm_actions = var.alarm_actions

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-sagemaker-high-latency"
    }
  )
}

# CloudWatch Alarm - Invocations (Low Activity Alert)
resource "aws_cloudwatch_metric_alarm" "low_invocations" {
  count               = var.enable_low_invocation_alarm ? 1 : 0
  alarm_name          = "${var.project_name}-sagemaker-low-invocations"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Invocations"
  namespace           = "AWS/SageMaker"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alert when endpoint receives very few invocations (possible issue)"
  treat_missing_data  = "breaching"

  dimensions = {
    EndpointName = aws_sagemaker_endpoint.whisper.name
    VariantName  = "AllTraffic"
  }

  alarm_actions = var.alarm_actions

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-sagemaker-low-invocations"
    }
  )
}
