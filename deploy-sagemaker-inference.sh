#!/bin/bash

# Exit immediately if any command exits with a non-zero status
set -e

export AWS_REGION="eu-west-1"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_REPOSITORY="whisper-sagemaker-inference"

# Create ECR repository if it doesn't exist
echo "Creating ECR repository..."
aws ecr create-repository \
  --repository-name ${ECR_REPOSITORY} \
  --region ${AWS_REGION} 2>/dev/null || echo "Repository already exists"

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin \
  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Build image with single-platform manifest (required by SageMaker)
echo "Building SageMaker inference Docker image (linux/amd64)..."
docker build --provenance=false --platform linux/amd64 \
  -f ml-model/Dockerfile.sagemaker \
  -t ${ECR_REPOSITORY}:latest ml-model

# Tag for ECR
echo "Tagging image for ECR..."
docker tag ${ECR_REPOSITORY}:latest \
  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:latest

# Push to ECR
echo "Pushing image to ECR..."
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:latest

echo "SageMaker inference image pushed successfully!"
echo "Image URI: ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:latest"
