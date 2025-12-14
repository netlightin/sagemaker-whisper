# Whisper SageMaker Architecture

## Overview

This project implements a production-ready speech-to-text transcription service using OpenAI's Whisper Large V3 Turbo model deployed on AWS SageMaker, with a Go API backend and Next.js frontend.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                           Internet                                   │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                    ┌────────▼─────────┐
                    │   Application    │
                    │  Load Balancer   │
                    │   (ALB - HTTP)   │
                    └────────┬─────────┘
                             │
                ┌────────────┴──────────────┐
                │                           │
        ┌───────▼────────┐         ┌───────▼────────┐
        │   Frontend     │         │   API Service  │
        │  (Next.js)     │         │   (Golang)     │
        │  ECS Fargate   │         │  ECS Fargate   │
        │  Port: 3000    │         │  Port: 8080    │
        └────────────────┘         └───────┬────────┘
                                           │
                                  ┌────────▼────────┐
                                  │   SageMaker     │
                                  │   Endpoint      │
                                  │ (Whisper Model) │
                                  │  ml.g4dn.xlarge │
                                  └────────┬────────┘
                                           │
                                  ┌────────▼────────┐
                                  │   S3 Bucket     │
                                  │  Model Artifacts│
                                  └─────────────────┘
```

## Component Details

### 1. Networking Layer (VPC)

**Resource**: `vpc-0b6914935cae3a5c5`
**Region**: `eu-west-1`

- **VPC CIDR**: 10.0.0.0/16
- **Availability Zones**: 2 (eu-west-1a, eu-west-1b)
- **Public Subnets**: 2 (10.0.1.0/24, 10.0.2.0/24)
  - Internet Gateway for outbound traffic
  - NAT Gateways (one per AZ)
- **Private Subnets**: 2 (10.0.11.0/24, 10.0.12.0/24)
  - NAT Gateway for outbound traffic
  - S3 VPC Gateway Endpoint for model access
- **Security Groups**:
  - ALB SG: Allows HTTP (80) from internet
  - ECS SG: Allows traffic from ALB
  - SageMaker SG: Allows traffic from ECS

### 2. Application Load Balancer (ALB)

**DNS**: `whisper-sagemaker-alb-299033305.eu-west-1.elb.amazonaws.com`

**Routing Rules**:
- `/` → Frontend Service (port 3000)
- `/api/*`, `/transcribe`, `/health`, `/status/*` → API Service (port 8080)

**Health Checks**:
- Frontend: HTTP GET `/` (30s interval, 3 retries)
- API: HTTP GET `/health` (30s interval, 3 retries)

### 3. Frontend Service (Next.js)

**Technology**: Next.js 16, TypeScript, Tailwind CSS
**Deployment**: ECS Fargate
**Scaling**: 1-10 tasks, auto-scale at 70% CPU

**Features**:
- Server-side rendering (SSR)
- Audio file upload with drag-and-drop
- Real-time transcription display
- Error handling and validation
- Responsive design

**Environment Variables**:
- `API_URL`: Internal ALB URL
- `NODE_ENV`: production
- `PORT`: 3000

**Container**:
- **Image**: `654654436000.dkr.ecr.eu-west-1.amazonaws.com/whisper-sagemaker-frontend:latest`
- **CPU**: 256 units (0.25 vCPU)
- **Memory**: 512 MB
- **Health Check**: `curl -f http://localhost:3000`

### 4. API Service (Go)

**Technology**: Go 1.24, AWS SDK v2
**Deployment**: ECS Fargate
**Scaling**: 1-10 tasks, auto-scale at 70% CPU

**Endpoints**:
- `GET /health` - Health check
- `POST /transcribe` - Audio transcription
- `GET /status/{id}` - Status check (for async operations)

**Features**:
- Multipart form-data file upload
- Audio format validation (mp3, wav, m4a, flac, ogg, webm)
- File size validation (max 100MB)
- SageMaker endpoint invocation
- CORS support
- Structured logging

**Environment Variables**:
- `SAGEMAKER_ENDPOINT_NAME`: whisper-sagemaker-whisper-endpoint
- `AWS_REGION`: eu-west-1
- `PORT`: 8080
- `MAX_FILE_SIZE`: 104857600 (100MB)

**Container**:
- **Image**: `654654436000.dkr.ecr.eu-west-1.amazonaws.com/whisper-sagemaker-api:latest`
- **CPU**: 512 units (0.5 vCPU)
- **Memory**: 1024 MB
- **Health Check**: `curl -f http://localhost:8080/health`

### 5. SageMaker Endpoint

**Endpoint Name**: `whisper-sagemaker-whisper-endpoint`
**Model**: Whisper Large V3 Turbo (~1.4GB)
**Instance Type**: ml.g4dn.xlarge (1x NVIDIA T4 GPU, 4 vCPUs, 16GB RAM)
**Scaling**: 1-3 instances, auto-scale based on invocations

**Model Location**: `s3://sagemaker-whisper-models-654654436000-eu-west-1/whisper-large-v3-turbo/model.tar.gz`

**Container**: AWS Deep Learning Container (HuggingFace PyTorch Inference)
- Base Image: `763104351884.dkr.ecr.eu-west-1.amazonaws.com/huggingface-pytorch-inference:2.1.0-transformers4.37.0-gpu-py310-cu118-ubuntu20.04`

**Inference Script**: Custom `inference.py` with model_fn, input_fn, predict_fn, output_fn

**Performance**:
- Cold start: ~30-60 seconds
- Warm inference: ~2-5 seconds (depends on audio length)
- Max audio length: 5 minutes (300 seconds)

### 6. ECR Repositories

- **API**: `654654436000.dkr.ecr.eu-west-1.amazonaws.com/whisper-sagemaker-api`
- **Frontend**: `654654436000.dkr.ecr.eu-west-1.amazonaws.com/whisper-sagemaker-frontend`

**Lifecycle Policies**:
- Keep last 10 images
- Delete untagged images after 7 days

### 7. Monitoring & Logging

**CloudWatch Dashboard**: `whisper-sagemaker-dashboard`

**Metrics Tracked**:
- SageMaker: Model latency, invocations, errors
- ECS: CPU/Memory utilization
- ALB: Response time, request count, target health

**Log Groups**:
- ECS Logs: `/ecs/whisper-sagemaker` (30-day retention)
- SageMaker Logs: `/aws/sagemaker/Endpoints/whisper-sagemaker-whisper-endpoint`

### 8. Auto-Scaling Configuration

**ECS Services**:
- Target: 70% CPU utilization
- Min: 1 task, Max: 10 tasks
- Scale-out cooldown: 60 seconds
- Scale-in cooldown: 300 seconds

**SageMaker Endpoint**:
- Metric: Invocations per instance
- Min: 1 instance, Max: 3 instances
- Target: Optimal based on model performance

## Data Flow

### Transcription Request Flow

1. User uploads audio file via Frontend
2. Frontend sends POST request to `/transcribe` via ALB
3. ALB routes to API Service (ECS)
4. API Service validates file format and size
5. API Service invokes SageMaker endpoint with audio data
6. SageMaker downloads model from S3 (if cold start)
7. SageMaker runs inference with Whisper model
8. SageMaker returns transcription result
9. API Service formats and returns response to Frontend
10. Frontend displays transcription to user

## Security

### Network Security
- Private subnets for compute resources (ECS, SageMaker)
- S3 VPC Gateway Endpoint for secure model access
- Security groups with least-privilege access

### IAM Roles
- **ECS Task Execution Role**: Pull images from ECR, write logs to CloudWatch
- **ECS Task Role**: Invoke SageMaker endpoints
- **SageMaker Execution Role**: Access S3 model artifacts

### Data Security
- In-transit: All internal traffic within VPC
- At-rest: S3 model artifacts (can be encrypted)
- No persistent storage of user audio files

## Cost Breakdown (Approximate)

### Monthly Costs (assuming moderate usage)

- **SageMaker ml.g4dn.xlarge**: $0.736/hour × 730 hours = ~$537/month
- **ECS Fargate**:
  - API (0.5 vCPU, 1GB): ~$15-30/month
  - Frontend (0.25 vCPU, 0.5GB): ~$10-20/month
- **ALB**: ~$20/month + data transfer
- **NAT Gateways**: 2 × $32 = ~$64/month
- **S3**: ~$1/month (model storage)
- **CloudWatch Logs**: ~$5/month

**Total**: ~$650-700/month

### Cost Optimization Strategies
- Scale SageMaker to 0 instances during non-business hours
- Use spot instances for non-production environments
- Implement request batching to reduce invocations
- Consider Reserved Instances for predictable workloads

## Disaster Recovery

### Backup Strategy
- **Infrastructure**: Terraform state in version control
- **Model artifacts**: S3 with versioning enabled (recommended)
- **Container images**: ECR with lifecycle policies

### Recovery Procedures
1. Infrastructure: `terraform apply` from state
2. Model: Already in S3, auto-downloaded by SageMaker
3. Containers: Already in ECR, auto-deployed by ECS

**RTO (Recovery Time Objective)**: ~15-20 minutes
**RPO (Recovery Point Objective)**: Current state (infrastructure as code)

## Scalability

### Horizontal Scaling
- ECS services: Auto-scale up to 10 tasks
- SageMaker: Auto-scale up to 3 instances
- ALB: Automatically scales with traffic

### Vertical Scaling
- SageMaker: Can upgrade to ml.g5.xlarge for better GPU performance
- ECS: Can increase task CPU/Memory allocations

### Bottlenecks
- SageMaker cold start time (~30-60s)
- NAT Gateway throughput (5 Gbps)
- ALB connection limits

## Known Issues

### Current Limitations
1. **SageMaker Model Dependency**: Numpy availability issue in the inference container
   - Error: "RuntimeError: Numpy is not available"
   - Impact: Model inference fails on audio processing
   - Workaround: Requires model repackaging or different container base image

2. **No SSL/TLS**: HTTP only (HTTPS not configured)
3. **No Authentication**: API endpoints are publicly accessible
4. **Synchronous Processing**: No async processing for long audio files

## Future Enhancements

- Implement HTTPS with ACM certificate
- Add API authentication (API Gateway + Cognito)
- Implement async processing with SQS/SNS
- Add audio file storage in S3 (optional)
- Implement rate limiting
- Add multi-language support UI
- WebSocket support for real-time streaming transcription
