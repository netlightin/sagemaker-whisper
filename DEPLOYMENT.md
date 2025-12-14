# Deployment Runbook

## Prerequisites

### Required Tools

- AWS CLI v2 (configured with SSO or credentials)
- Terraform >= 1.5.0
- Docker
- Go 1.24+
- Node.js 20+
- Python 3.10+ (for model packaging)

### AWS Permissions Required

- EC2 (VPC, Security Groups, NAT Gateway)
- ECS (Cluster, Services, Task Definitions)
- ECR (Repository management)
- SageMaker (Model, Endpoint, Endpoint Config)
- IAM (Roles, Policies)
- CloudWatch (Logs, Dashboards, Alarms)
- S3 (Bucket creation, object upload)
- Application Load Balancer

### Environment Setup

```bash
# Configure AWS CLI
aws configure sso

# Verify access
aws sts get-caller-identity

# Set region
export AWS_REGION=eu-west-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
```

## Initial Deployment

### Step 1: Prepare Whisper Model

```bash
sh deploy-model.sh
```

### Step 2: Build and Push Docker Images

#### Build API Image

```bash
sh deploy-api.sh
```

#### Build Frontend Image

```bash
sh deploy-frontend.sh
```

#### Build SageMaker Inference Image

```bash
sh deploy-whisper-sagemaker-inference.sh
```

### Step 3: Deploy Infrastructure with Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Apply infrastructure
terraform apply
```

**Resources Created**:

- VPC with public/private subnets across 2 AZs
- NAT Gateways (2)
- Application Load Balancer
- ECR Repositories (2)
- ECS Cluster
- ECS Services (API, Frontend)
- SageMaker Model, Endpoint Configuration, Endpoint
- CloudWatch Log Groups and Dashboard
- IAM Roles and Policies

**Expected Time**: 15-20 minutes

- Most resources: 5-10 minutes
- SageMaker Endpoint: 10-15 minutes (model download + initialization)

### Step 4: Verify Deployment

```bash
# Get ALB URL
ALB_URL=$(terraform output -raw alb_url)
echo "Application URL: ${ALB_URL}"

# Test API health
curl ${ALB_URL}/health

# Test frontend
curl -I ${ALB_URL}/

# Check ECS services
aws ecs describe-services \
  --cluster whisper-sagemaker-cluster \
  --services whisper-sagemaker-api-service whisper-sagemaker-frontend-service \
  --region ${AWS_REGION} \
  --query 'services[*].{Name:serviceName,Status:status,Running:runningCount,Desired:desiredCount}'

# Check SageMaker endpoint
aws sagemaker describe-endpoint \
  --endpoint-name whisper-sagemaker-whisper-endpoint \
  --region ${AWS_REGION} \
  --query 'EndpointStatus'
```

**Expected Output**:

- Health check: `{"status":"healthy","endpoint":"whisper-sagemaker-whisper-endpoint"}`
- Frontend: HTTP 200
- ECS services: ACTIVE with Running = Desired
- SageMaker: InService

### Step 5: Access Application

Open browser and navigate to: `http://<ALB_DNS_NAME>`

## Updating the Application

### Update API Code

```bash
cd api

# Make code changes
# ...

# Rebuild image
docker build -t whisper-sagemaker-api:latest .

# Tag with version
docker tag whisper-sagemaker-api:latest \
  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/whisper-sagemaker-api:v1.1.0

# Tag as latest
docker tag whisper-sagemaker-api:latest \
  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/whisper-sagemaker-api:latest

# Push both tags
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/whisper-sagemaker-api:v1.1.0
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/whisper-sagemaker-api:latest

# Force new deployment in ECS
aws ecs update-service \
  --cluster whisper-sagemaker-cluster \
  --service whisper-sagemaker-api-service \
  --force-new-deployment \
  --region ${AWS_REGION}

# Monitor deployment
aws ecs wait services-stable \
  --cluster whisper-sagemaker-cluster \
  --services whisper-sagemaker-api-service \
  --region ${AWS_REGION}
```

**Deployment Strategy**: Rolling update

- ECS maintains minimum healthy percent (100%)
- Deploys new tasks before stopping old ones
- Zero downtime deployment

**Expected Time**: 3-5 minutes

### Update Frontend Code

Same process as API, replace `api` with `frontend` and `8080` with `3000`.

### Update Infrastructure

```bash
cd terraform

# Review changes
terraform plan

# Apply changes
terraform apply

# Specific resource updates
terraform apply -target=module.ecs.aws_ecs_service.api
```

## Rollback Procedures

### Rollback API/Frontend (ECS)

```bash
# List task definition revisions
aws ecs list-task-definitions \
  --family-prefix whisper-sagemaker-api \
  --region ${AWS_REGION}

# Update service to previous revision
aws ecs update-service \
  --cluster whisper-sagemaker-cluster \
  --service whisper-sagemaker-api-service \
  --task-definition whisper-sagemaker-api:PREVIOUS_REVISION \
  --region ${AWS_REGION}

# Or use specific image version
docker pull ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/whisper-sagemaker-api:v1.0.0
# (then repeat deployment steps with old version)
```

### Rollback Infrastructure

```bash
cd terraform

# Revert code changes
git checkout HEAD~1 terraform/

# Apply previous state
terraform plan
terraform apply
```

### Rollback SageMaker Model

```bash
# Update model data URL in terraform
# terraform/variables.tf or terraform.tfvars

model_data_url = "s3://bucket/old-model-version/model.tar.gz"

# Apply changes
cd terraform
terraform apply -target=module.sagemaker
```

## Scaling Operations

### Scale ECS Services Manually

```bash
# Scale API service
aws ecs update-service \
  --cluster whisper-sagemaker-cluster \
  --service whisper-sagemaker-api-service \
  --desired-count 5 \
  --region ${AWS_REGION}

# Scale Frontend service
aws ecs update-service \
  --cluster whisper-sagemaker-cluster \
  --service whisper-sagemaker-frontend-service \
  --desired-count 3 \
  --region ${AWS_REGION}
```

### Scale SageMaker Endpoint

```bash
# Update endpoint to use more instances
aws sagemaker update-endpoint-weights-and-capacities \
  --endpoint-name whisper-sagemaker-whisper-endpoint \
  --desired-weights-and-capacities \
    VariantName=AllTraffic,DesiredInstanceCount=2 \
  --region ${AWS_REGION}
```

### Update Auto-Scaling Policies

```bash
cd terraform

# Edit auto-scaling configuration in terraform/modules/ecs/main.tf
# or terraform/modules/sagemaker/main.tf

# Apply changes
terraform apply
```

## Maintenance Tasks

### View Logs

```bash
# ECS API logs
aws logs tail /ecs/whisper-sagemaker \
  --follow \
  --filter-pattern "api" \
  --region ${AWS_REGION}

# SageMaker endpoint logs
aws logs tail /aws/sagemaker/Endpoints/whisper-sagemaker-whisper-endpoint \
  --follow \
  --region ${AWS_REGION}
```

### Check Resource Utilization

```bash
# ECS service metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=whisper-sagemaker-api-service \
               Name=ClusterName,Value=whisper-sagemaker-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region ${AWS_REGION}

# SageMaker endpoint metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/SageMaker \
  --metric-name ModelLatency \
  --dimensions Name=EndpointName,Value=whisper-sagemaker-whisper-endpoint \
               Name=VariantName,Value=AllTraffic \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region ${AWS_REGION}
```

### Clean Up Old Images

```bash
# ECR lifecycle policies handle this automatically
# Manual cleanup if needed:

aws ecr list-images \
  --repository-name whisper-sagemaker-api \
  --region ${AWS_REGION} \
  --query 'imageIds[?type(imageTag)!=`string`].[imageDigest]' \
  --output text | \
  xargs -I {} aws ecr batch-delete-image \
    --repository-name whisper-sagemaker-api \
    --image-ids imageDigest={} \
    --region ${AWS_REGION}
```

## Disaster Recovery

### Backup Current State

```bash
# Export Terraform state (if using local state)
cd terraform
terraform state pull > backup-$(date +%Y%m%d).tfstate

# Backup environment variables
terraform output -json > outputs-$(date +%Y%m%d).json

# Commit code changes
git add .
git commit -m "Backup before maintenance"
git push
```

### Restore from Disaster

```bash
# 1. Ensure Terraform state is available
cd terraform

# 2. Verify/create S3 bucket for model
aws s3 ls s3://sagemaker-whisper-models-${AWS_ACCOUNT_ID}-${AWS_REGION} || \
  aws s3 mb s3://sagemaker-whisper-models-${AWS_ACCOUNT_ID}-${AWS_REGION}

# 3. Upload model if missing
aws s3 ls s3://sagemaker-whisper-models-${AWS_ACCOUNT_ID}-${AWS_REGION}/whisper-large-v3-turbo/model.tar.gz || \
  (cd ../ml-model && python scripts/download_and_package_model.py --s3-bucket sagemaker-whisper-models-${AWS_ACCOUNT_ID}-${AWS_REGION})

# 4. Rebuild and push Docker images
./rebuild-and-push.sh  # (create this script from deployment steps)

# 5. Restore infrastructure
terraform init
terraform plan
terraform apply -auto-approve

# 6. Verify all services
./verify-deployment.sh  # (create this script from verification steps)
```

## Decommissioning

### Destroy All Resources

```bash
cd terraform

# Review what will be destroyed
terraform plan -destroy

# Destroy infrastructure
terraform destroy

# Confirm deletion of:
# - ECS services and tasks
# - SageMaker endpoint (stops billing)
# - NAT Gateways (stops billing)
# - ALB (stops billing)
# - All other resources

# Manually clean up if needed:
# - S3 model bucket (if terraform can't delete due to versioning)
aws s3 rm s3://sagemaker-whisper-models-${AWS_ACCOUNT_ID}-${AWS_REGION} --recursive
aws s3 rb s3://sagemaker-whisper-models-${AWS_ACCOUNT_ID}-${AWS_REGION}

# - ECR images
aws ecr delete-repository \
  --repository-name whisper-sagemaker-api \
  --force \
  --region ${AWS_REGION}

aws ecr delete-repository \
  --repository-name whisper-sagemaker-frontend \
  --force \
  --region ${AWS_REGION}
```

**Expected Time**: 10-15 minutes

## Troubleshooting

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for common issues and solutions.

## Security Checklist

Before production deployment:

- [ ] Enable HTTPS with ACM certificate
- [ ] Configure WAF rules on ALB
- [ ] Implement API authentication (API Gateway + Cognito)
- [ ] Enable S3 encryption for model bucket
- [ ] Enable CloudTrail logging
- [ ] Set up AWS Config rules
- [ ] Configure VPC Flow Logs
- [ ] Review and minimize IAM permissions
- [ ] Enable ECS container insights
- [ ] Set up AWS GuardDuty
- [ ] Implement rate limiting
- [ ] Configure DDoS protection (Shield)

## Monitoring Checklist

- [ ] CloudWatch Dashboard configured and accessible
- [ ] Log aggregation working (ECS, SageMaker)
- [ ] Auto-scaling policies tested
- [ ] Alarms configured for critical metrics
- [ ] SNS notifications set up
- [ ] Cost alerts configured in AWS Budgets
- [ ] Regular cost reviews scheduled
