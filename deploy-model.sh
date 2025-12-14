#!/bin/bash

# Exit immediately if any command exits with a non-zero status
set -e

export AWS_REGION="eu-west-1"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export BUCKET_NAME="sagemaker-whisper-models-${AWS_ACCOUNT_ID}-${AWS_REGION}"

# Create S3 bucket if it doesn't exist
echo "Creating S3 bucket..."
aws s3api create-bucket \
  --bucket "${BUCKET_NAME}" \
  --region "${AWS_REGION}" \
  --create-bucket-configuration LocationConstraint="${AWS_REGION}" 2>/dev/null || echo "Bucket already exists"

# Block public access
echo "Blocking public access..."
aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Build the Docker image
echo "Building Docker image..."
docker build -f ml-model/Dockerfile.download -t whisper-model-downloader:latest ml-model

# Run the Docker container to download and package the model files
echo "Downloading and packaging model (this may take 10-15 minutes)..."
docker run \
  -v "$(pwd)/ml-model:/app" \
  whisper-model-downloader:latest \
  --s3-bucket "${BUCKET_NAME}" \
  --skip-upload

# Upload model files to S3
echo "Uploading model to S3..."
aws s3 cp \
  ./ml-model/whisper-large-v3-turbo-model.tar.gz \
  s3://${BUCKET_NAME}/whisper-large-v3-turbo/model.tar.gz

# Get the S3 URI for Terraform
S3_MODEL_URI="s3://${BUCKET_NAME}/whisper-large-v3-turbo/model.tar.gz"
echo "S3 URI: ${S3_MODEL_URI}"
