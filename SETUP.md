# Complete Deployment Guide - Whisper SageMaker

A step-by-step guide to deploy the Whisper SageMaker application from scratch on AWS. This guide covers every step needed to reproduce the deployment including S3 setup, ECR image building, and Terraform infrastructure deployment.

## Prerequisites

Before starting, ensure you have:

1. **AWS Account** with appropriate permissions (Admin access recommended for initial setup)
2. **AWS CLI v2** installed and configured
3. **Terraform** (v1.0+) installed
4. **Docker Desktop** installed and running
5. **Git** installed
6. **Python 3.10+** for local scripts
7. **Go 1.24** (for API builds, if needed locally)
8. **Node.js 18+** (for Frontend builds, if needed locally)

### AWS Credentials Setup

Configure AWS credentials locally:

```bash
aws configure
```

You'll be prompted for:

- AWS Access Key ID
- AWS Secret Access Key
- Default region: `eu-west-1`
- Default output format: `json`

Verify configuration:

```bash
aws sts get-caller-identity
```

---

## Phase 1: AWS Account Setup

### 1.1 Create S3 Bucket for Model Artifacts

The Whisper model needs to be uploaded to S3 for SageMaker to access it.

```bash
# Set variables
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="eu-west-1"
BUCKET_NAME="sagemaker-whisper-models-${AWS_ACCOUNT_ID}-${AWS_REGION}"

# Create S3 bucket
aws s3api create-bucket \
  --bucket "${BUCKET_NAME}" \
  --region "${AWS_REGION}" \
  --create-bucket-configuration LocationConstraint="${AWS_REGION}"

# Block public access
aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled

echo "Bucket created: ${BUCKET_NAME}"
echo "AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}"
echo "AWS_REGION=${AWS_REGION}"
```

Save these values for later:

```bash
export AWS_ACCOUNT_ID="<value>"
export AWS_REGION="eu-west-1"
export BUCKET_NAME="sagemaker-whisper-models-${AWS_ACCOUNT_ID}-${AWS_REGION}"
```

---

## Phase 2: Download and Package Whisper Model

### 2.1 Download Whisper Model from Hugging Face

You have two options:

#### Option A: Using the Docker Script (Recommended)

```bash
cd ml-model

# Build the Docker image (one-time)
docker build -f Dockerfile.download -t whisper-model-downloader:latest .

export AWS_ACCOUNT_ID="654654436000"
export AWS_REGION="eu-west-1"
export BUCKET_NAME="sagemaker-whisper-models-${AWS_ACCOUNT_ID}-${AWS_REGION}"

echo "Creating S3 bucket: ${BUCKET_NAME}"

aws s3api create-bucket \
  --bucket "${BUCKET_NAME}" \
  --region "${AWS_REGION}" \
  --create-bucket-configuration LocationConstraint="${AWS_REGION}"


aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"


aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled


# Run the downloader container (this will download and package the model)
# For users with AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY:
docker run \
  -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
  -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
  -e AWS_DEFAULT_REGION=${AWS_REGION} \
  whisper-model-downloader:latest \
  --s3-bucket sagemaker-whisper-models-${AWS_ACCOUNT_ID}-${AWS_REGION}

# For SSO users (mount your local AWS credentials and config):
docker run \
  -v ~/.aws:/root/.aws:ro \
  -e AWS_DEFAULT_REGION=${AWS_REGION} \
  -e AWS_PROFILE=${AWS_PROFILE:-default} \
  whisper-model-downloader:latest \
  --s3-bucket sagemaker-whisper-models-${AWS_ACCOUNT_ID}-${AWS_REGION}

# If the above fails with "Unable to locate credentials", first refresh your SSO login:
aws sso login --profile ${AWS_PROFILE:-default}

# Then try the docker run command again

# Or skip S3 upload for testing (no AWS credentials needed):
docker run \
  -v $(pwd)/whisper:/app/whisper \
  whisper-model-downloader:latest \
  --s3-bucket sagemaker-whisper-models-${AWS_ACCOUNT_ID}-${AWS_REGION} \
  --skip-upload
```

#### Option B: Using Local Python

```bash
cd ml-model

# Create virtual environment (if not already created)
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install --upgrade pip
pip install transformers==4.37.0 torch==2.1.0 torchaudio==2.1.0 soundfile librosa scipy boto3

# Run the download script
python scripts/download_and_package_model.py \
  --s3-bucket sagemaker-whisper-models-${AWS_ACCOUNT_ID}-${AWS_REGION}
```

### 2.2 Verify Model Upload

The download script handles packaging and uploading automatically. Verify the model is in S3:

```bash
# Check that model.tar.gz was uploaded to S3
aws s3 ls s3://${BUCKET_NAME}/whisper-large-v3-turbo/ --region ${AWS_REGION}

# Expected output:
# 2025-12-12 12:34:56    1234567890 model.tar.gz

# Get the S3 URI for later use
S3_MODEL_URI="s3://${BUCKET_NAME}/whisper-large-v3-turbo/model.tar.gz"
echo "Model S3 URI: ${S3_MODEL_URI}"
```

---

## Phase 3: Build and Push Docker Images to ECR

### 3.1 Create ECR Repositories

ECR repositories will be created by Terraform, but we can create them manually if needed:

```bash
# Create API ECR repository
aws ecr create-repository \
  --repository-name whisper-sagemaker-api \
  --region ${AWS_REGION} 2>/dev/null || echo "API repo already exists"

# Create Frontend ECR repository
aws ecr create-repository \
  --repository-name whisper-sagemaker-frontend \
  --region ${AWS_REGION} 2>/dev/null || echo "Frontend repo already exists"

# Create SageMaker Inference ECR repository
aws ecr create-repository \
  --repository-name whisper-sagemaker-inference \
  --region ${AWS_REGION} 2>/dev/null || echo "Inference repo already exists"

# List repositories
aws ecr describe-repositories --region ${AWS_REGION} --query 'repositories[*].repositoryUri' --output table
```

### 3.2 Login to ECR

```bash
# Get ECR login token and authenticate Docker
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

echo "Docker login successful!"
```

### 3.3 Build and Push API Docker Image

```bash
# From project root
cd api

# Build the API image
docker build -t whisper-sagemaker-api:latest .

# Tag the image for ECR
docker tag whisper-sagemaker-api:latest \
  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/whisper-sagemaker-api:latest

# Push to ECR
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/whisper-sagemaker-api:latest

echo "API image pushed to ECR!"
```

### 3.4 Build and Push Frontend Docker Image

```bash
# From project root
cd frontend

# Build the Frontend image
docker build -t whisper-sagemaker-frontend:latest .

# Tag the image for ECR
docker tag whisper-sagemaker-frontend:latest \
  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/whisper-sagemaker-frontend:latest

# Push to ECR
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/whisper-sagemaker-frontend:latest

echo "Frontend image pushed to ECR!"
```

### 3.5 Build and Push SageMaker Inference Docker Image

```bash
# From project root
cd ml-model

# Build the SageMaker inference image with single-platform manifest (required by SageMaker)
docker build --provenance=false --platform linux/amd64 \
  -f Dockerfile.sagemaker \
  -t whisper-sagemaker-inference:latest .

# Tag the image for ECR
docker tag whisper-sagemaker-inference:latest \
  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/whisper-sagemaker-inference:latest

# Push to ECR
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/whisper-sagemaker-inference:latest

echo "SageMaker inference image pushed to ECR!"
```

### 3.6 Verify All Images in ECR

```bash
# List all images in ECR
aws ecr describe-images \
  --repository-name whisper-sagemaker-api \
  --region ${AWS_REGION} \
  --query 'imageDetails[*].[imageTags,imageSizeInBytes,imageDigest]' \
  --output table

aws ecr describe-images \
  --repository-name whisper-sagemaker-frontend \
  --region ${AWS_REGION} \
  --query 'imageDetails[*].[imageTags,imageSizeInBytes,imageDigest]' \
  --output table

aws ecr describe-images \
  --repository-name whisper-sagemaker-inference \
  --region ${AWS_REGION} \
  --query 'imageDetails[*].[imageTags,imageSizeInBytes,imageDigest]' \
  --output table
```

---

## Phase 4: Deploy Infrastructure with Terraform

### 4.1 Initialize Terraform

```bash
# From project root
cd terraform

# Initialize Terraform working directory
terraform init

# Validate Terraform configuration
terraform validate

echo "Terraform initialized!"
```

### 4.2 Create Terraform Variables File

Create `terraform/terraform.tfvars`:

```hcl
aws_region                       = "eu-west-1"
aws_account_id                   = "654654436000"  # Replace with your account ID
project_name                     = "whisper-sagemaker"
environment                      = "production"

# Networking
vpc_cidr                         = "10.0.0.0/16"
availability_zones               = ["eu-west-1a", "eu-west-1b"]

# SageMaker
sagemaker_model_bucket           = "sagemaker-whisper-models-654654436000-eu-west-1"
sagemaker_model_s3_uri           = "s3://sagemaker-whisper-models-654654436000-eu-west-1/whisper-large-v3-turbo/model.tar.gz"
sagemaker_instance_type          = "ml.g4dn.xlarge"
sagemaker_initial_instance_count = 1

# ECS API
ecs_api_image                    = "654654436000.dkr.ecr.eu-west-1.amazonaws.com/whisper-sagemaker-api:latest"
ecs_api_container_port           = 8080
ecs_api_desired_count            = 2
ecs_api_cpu                      = 512
ecs_api_memory                   = 1024

# ECS Frontend
ecs_frontend_image               = "654654436000.dkr.ecr.eu-west-1.amazonaws.com/whisper-sagemaker-frontend:latest"
ecs_frontend_container_port      = 3000
ecs_frontend_desired_count       = 2
ecs_frontend_cpu                 = 512
ecs_frontend_memory              = 1024

# Docker Image for SageMaker
sagemaker_image_uri              = "654654436000.dkr.ecr.eu-west-1.amazonaws.com/whisper-sagemaker-inference:latest"

tags = {
  Environment = "production"
  ManagedBy   = "Terraform"
  Project     = "whisper-sagemaker"
}
```

**Important:** Replace `654654436000` with your actual AWS Account ID and update the image URIs if they differ.

### 4.3 Review Terraform Plan

```bash
# Generate and review the Terraform plan
terraform plan -out=tfplan

# This will show you all resources that will be created
# Review carefully and ensure everything looks correct
```

### 4.4 Apply Terraform Configuration

```bash
# Apply the Terraform plan (this will create all AWS resources)
terraform apply tfplan

# Terraform will create:
# - VPC with public/private subnets in 2 AZs
# - Internet Gateway and NAT Gateways
# - Security Groups
# - ECR repositories (if not already created)
# - SageMaker Model, Endpoint Configuration, and Endpoint
# - ECS Cluster and Services
# - Application Load Balancer
# - CloudWatch Log Groups
# - IAM Roles and Policies

# Wait for completion (typically 20-30 minutes for SageMaker endpoint)
```

### 4.5 Verify Terraform Outputs

```bash
# Display Terraform outputs
terraform output

# Save key outputs for later use
terraform output -json > terraform-outputs.json

# Key outputs to note:
# - alb_url: Application Load Balancer URL
# - sagemaker_endpoint_name: SageMaker endpoint name
# - ecs_cluster_name: ECS cluster name
```

---

## Phase 5: Verify Deployment

### 5.1 Check SageMaker Endpoint Status

```bash
# Get SageMaker endpoint status
aws sagemaker describe-endpoint \
  --endpoint-name whisper-sagemaker-whisper-endpoint \
  --region ${AWS_REGION} \
  --query 'EndpointStatus' \
  --output text

# Wait until status is "InService" (can take 20-30 minutes)
# Check periodically with:
while true; do
  status=$(aws sagemaker describe-endpoint \
    --endpoint-name whisper-sagemaker-whisper-endpoint \
    --region ${AWS_REGION} \
    --query 'EndpointStatus' \
    --output text)
  echo "Status: $status"
  if [ "$status" == "InService" ]; then
    echo "Endpoint is ready!"
    break
  fi
  sleep 30
done
```

### 5.2 Check ECS Services Status

```bash
# Check API service
aws ecs describe-services \
  --cluster whisper-sagemaker-cluster \
  --services whisper-sagemaker-api-service \
  --region ${AWS_REGION} \
  --query 'services[0].{status:status,runningCount:runningCount,desiredCount:desiredCount}' \
  --output table

# Check Frontend service
aws ecs describe-services \
  --cluster whisper-sagemaker-cluster \
  --services whisper-sagemaker-frontend-service \
  --region ${AWS_REGION} \
  --query 'services[0].{status:status,runningCount:runningCount,desiredCount:desiredCount}' \
  --output table
```

### 5.3 Get Application URL

```bash
# Get the ALB URL
ALB_URL=$(terraform output -raw alb_url)
echo "Application URL: ${ALB_URL}"

# Access the frontend
echo "Open browser at: http://${ALB_URL}"

# Test the API
curl -X GET "${ALB_URL}/health"
```

### 5.4 Test Transcription Endpoint

```bash
# Create a test audio file (or use an existing one)
ALB_URL=$(terraform output -raw alb_url)

# Test with a sample MP3 file
curl -X POST "${ALB_URL}/transcribe" \
  -F "audio=@/path/to/test-audio.mp3" \
  -H "Accept: application/json"

# Expected response:
# {
#   "text": "Transcribed text...",
#   "language": "en",
#   "duration": 45.2
# }
```

---

## Phase 6: Monitor and Troubleshoot

### 6.1 View CloudWatch Logs

```bash
# View SageMaker endpoint logs
aws logs tail /aws/sagemaker/Endpoints/whisper-sagemaker-whisper-endpoint \
  --region ${AWS_REGION} \
  --follow

# View ECS logs
aws logs tail /ecs/whisper-sagemaker \
  --region ${AWS_REGION} \
  --follow
```

### 6.2 Check CloudWatch Dashboard

```bash
# Get dashboard name from Terraform outputs
DASHBOARD_NAME=$(terraform output -raw cloudwatch_dashboard_name)

# Open the dashboard (replace ${AWS_REGION} with your region):
echo "Open: https://console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#dashboards:name=${DASHBOARD_NAME}"
```

### 6.3 Common Issues and Solutions

#### SageMaker Endpoint Stuck in "Creating" Status

```bash
# Check CloudWatch logs for errors
aws logs tail /aws/sagemaker/Endpoints/whisper-sagemaker-whisper-endpoint \
  --region ${AWS_REGION} --since 30m

# If stuck for >30 minutes, check the container can start:
# - Verify Docker image URI in Terraform
# - Check image exists in ECR
# - Check image is built for linux/amd64 (not arm64)
```

#### ECS Tasks Failing to Start

```bash
# Check task definition
aws ecs describe-task-definition \
  --task-definition whisper-sagemaker-api \
  --region ${AWS_REGION} \
  --query 'taskDefinition.containerDefinitions[0].image' \
  --output text

# Check ECS service events
aws ecs describe-services \
  --cluster whisper-sagemaker-cluster \
  --services whisper-sagemaker-api-service \
  --region ${AWS_REGION} \
  --query 'services[0].events[0:5]' \
  --output table

# Check ECS logs
aws logs tail /ecs/whisper-sagemaker \
  --region ${AWS_REGION} --since 30m
```

#### API Returns Empty Transcription

```bash
# Check if the SageMaker endpoint is receiving requests
aws logs tail /aws/sagemaker/Endpoints/whisper-sagemaker-whisper-endpoint \
  --region ${AWS_REGION} --since 10m

# Check if the audio file is valid
file /path/to/test-audio.mp3
ffprobe /path/to/test-audio.mp3  # If ffmpeg installed
```

---

## Phase 7: Post-Deployment Steps

### 7.1 Enable HTTPS (Optional but Recommended)

Request an SSL certificate from AWS Certificate Manager:

```bash
# Request ACM certificate for your domain
aws acm request-certificate \
  --domain-name example.com \
  --validation-method DNS \
  --region ${AWS_REGION}

# Add certificate to ALB listener in Terraform
# Then run: terraform apply
```

### 7.2 Configure Custom Domain (Optional)

```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)

# Create Route53 record pointing to ALB
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch "{
    \"Changes\": [{
      \"Action\": \"CREATE\",
      \"ResourceRecordSet\": {
        \"Name\": \"transcribe.example.com\",
        \"Type\": \"CNAME\",
        \"TTL\": 300,
        \"ResourceRecords\": [{\"Value\": \"${ALB_DNS}\"}]
      }
    }]
  }"
```

### 7.3 Set Up Alerts (Optional)

```bash
# SNS topic for alerts
aws sns create-topic \
  --name whisper-sagemaker-alerts \
  --region ${AWS_REGION}

# Subscribe to alerts
aws sns subscribe \
  --topic-arn arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT_ID}:whisper-sagemaker-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com
```

### 7.4 Configure Auto-Scaling (Already Done by Terraform)

Verify auto-scaling is configured:

```bash
# Check SageMaker auto-scaling
aws application-autoscaling describe-scalable-targets \
  --service-namespace sagemaker \
  --region ${AWS_REGION}

# Check ECS auto-scaling
aws application-autoscaling describe-scalable-targets \
  --service-namespace ecs \
  --region ${AWS_REGION}
```

---

## Phase 8: Cleanup (When Needed)

### 8.1 Destroy AWS Resources

```bash
# Destroy all resources created by Terraform
cd terraform

# First, check what will be destroyed
terraform plan -destroy

# Destroy resources
terraform destroy

# This will delete:
# - VPC and networking
# - ECS cluster and services
# - SageMaker endpoint, model, and configuration
# - ECR repositories (optional, can be kept)
# - Load Balancer
# - Security Groups
# - IAM Roles

# WARNING: This is irreversible!
```

### 8.2 Delete S3 Bucket with Model

```bash
# Empty the S3 bucket first
aws s3 rm s3://${BUCKET_NAME} --recursive

# Delete the bucket
aws s3api delete-bucket \
  --bucket ${BUCKET_NAME} \
  --region ${AWS_REGION}
```

### 8.3 Delete ECR Repositories (Optional)

```bash
# Delete API ECR repository
aws ecr delete-repository \
  --repository-name whisper-sagemaker-api \
  --region ${AWS_REGION} \
  --force

# Delete Frontend ECR repository
aws ecr delete-repository \
  --repository-name whisper-sagemaker-frontend \
  --region ${AWS_REGION} \
  --force

# Delete Inference ECR repository
aws ecr delete-repository \
  --repository-name whisper-sagemaker-inference \
  --region ${AWS_REGION} \
  --force
```

---

## Summary

You now have a complete Whisper transcription service deployed on AWS! Here's what was created:

### Infrastructure Created

- **VPC**: Multi-AZ with public and private subnets
- **SageMaker**: Whisper Large V3 Turbo model endpoint with auto-scaling
- **ECS Fargate**: API and Frontend services with auto-scaling
- **Load Balancer**: Application Load Balancer with routing rules
- **S3**: Model artifacts bucket
- **ECR**: Docker image repositories
- **CloudWatch**: Logs and dashboards
- **IAM**: Roles and policies for cross-service access

### Key Endpoints

- **Frontend**: http://{ALB_URL}
- **API Health**: http://{ALB_URL}/health
- **Transcribe**: http://{ALB_URL}/transcribe (POST)

### Estimated Costs

- **SageMaker** (ml.g4dn.xlarge): ~$0.736/hour ($528/month 24/7)
- **ECS Fargate**: ~$0.03-0.05/hour per task ($22-36/month)
- **Load Balancer**: ~$22.50/month
- **Data Transfer**: ~$0.02/GB

**Total (24/7 operation)**: ~$570-600/month

### Next Steps

1. Monitor the application in CloudWatch
2. Test with various audio formats
3. Set up monitoring and alerting
4. Configure custom domain and HTTPS
5. Implement authentication if needed
6. Optimize instance sizes based on workload

---

## Troubleshooting Quick Reference

| Issue                                  | Solution                                                                           |
| -------------------------------------- | ---------------------------------------------------------------------------------- |
| SageMaker endpoint stuck in "Creating" | Check CloudWatch logs, verify image URI and format                                 |
| ECS tasks failing                      | Check ECS logs, verify image exists in ECR, check IAM permissions                  |
| Empty transcription response           | Ensure SageMaker endpoint is InService, verify audio file is valid                 |
| API timeout                            | Check SageMaker endpoint latency, increase task timeout                            |
| High costs                             | Reduce auto-scaling max instances, use spot instances, scale down during off-hours |

---

## Additional Resources

- [Whisper Model Documentation](https://huggingface.co/openai/whisper-large-v3-turbo)
- [AWS SageMaker Documentation](https://docs.aws.amazon.com/sagemaker/)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

---

**Last Updated**: December 2025
**Version**: 1.0
