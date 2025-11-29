# Whisper on AWS SageMaker - Project Plan

## Project Overview

Deploy OpenAI's Whisper Large V3 Turbo model to AWS SageMaker with a full-stack application that enables users to transcribe audio files.

## Tech Stack

- **Infrastructure**: Terraform
- **ML Hosting**: AWS SageMaker (Whisper model)
- **API Hosting**: AWS ECS (Golang)
- **Frontend Hosting**: AWS ECS (Next.js SSR)
- **Languages**: Python (ML), Go (API), TypeScript (Frontend)

---

## Project Milestones

### Phase 1: Setup & Prerequisites

**Goal**: Prepare development environment and AWS account

#### 1.1 Project Repository Structure

```
.
├── terraform/
│   ├── modules/
│   │   ├── sagemaker/
│   │   ├── ecs/
│   │   ├── networking/
│   │   └── ecr/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── ml-model/
│   ├── whisper/
│   │   ├── model/
│   │   ├── inference.py
│   │   ├── requirements.txt
│   │   └── Dockerfile
│   └── scripts/
├── api/
│   ├── src/
│   ├── Dockerfile
│   └── (go.mod or package.json)
├── frontend/
│   ├── src/
│   ├── public/
│   ├── Dockerfile
│   └── package.json
└── docs/
```

- [x] Create repository structure
- [x] Initialize git repository
- [x] Create .gitignore file

---

### Phase 2: Whisper Model Preparation

**Goal**: Prepare Whisper model for SageMaker deployment

#### 2.1 SageMaker Inference Code

- [x] Create `inference.py` with model loading logic
- [x] Implement `model_fn()` to load Whisper model
- [x] Implement `input_fn()` to handle audio input (base64, raw bytes, S3 URLs)
- [x] Implement `predict_fn()` for transcription
- [x] Implement `output_fn()` to format JSON response
- [x] Add error handling and logging
- [x] Create `requirements.txt` with dependencies (transformers, torch, etc.)

#### 2.2 Model Packaging

- [x] Create model.tar.gz with model files and code
- [x] Test packaging script
- [x] Create S3 bucket for model artifacts
- [x] Upload model.tar.gz to S3

#### 2.3 Docker Container (if using custom container)

- [x] Create Dockerfile with Python base image
- [x] Install ML dependencies
- [x] Set up SageMaker serving framework
- [x] Build and test container locally
- [x] Push to AWS ECR

---

### Phase 3: Infrastructure as Code (Terraform)

**Goal**: Define all AWS resources using Terraform

#### 3.1 Core Networking

- [x] Create VPC module
- [x] Define public and private subnets (multi-AZ)
- [x] Create Internet Gateway
- [x] Create NAT Gateways
- [x] Configure route tables
- [x] Create security groups for SageMaker, ECS, ALB

#### 3.2 ECR Repositories

- [x] Create ECR repository for API container
- [x] Create ECR repository for Frontend container
- [x] Create ECR repository for Whisper inference (if custom)
- [x] Configure lifecycle policies

#### 3.3 SageMaker Resources

- [x] Create IAM role for SageMaker execution
- [x] Define SageMaker model resource
- [x] Define SageMaker endpoint configuration
  - [x] Choose instance type (ml.g4dn.xlarge or ml.g5.xlarge recommended)
  - [x] Configure auto-scaling settings
- [x] Define SageMaker endpoint
- [x] Add CloudWatch alarms for endpoint metrics

#### 3.4 ECS Cluster & Services

- [x] Create ECS cluster
- [x] Create IAM roles for ECS tasks
- [x] Define task definitions for API service
- [x] Define task definitions for Frontend service
- [x] Create ECS services with desired count
- [x] Configure auto-scaling policies

#### 3.5 Load Balancing

- [x] Create Application Load Balancer (ALB)
- [x] Create target groups for API and Frontend
- [x] Configure health checks
- [x] Set up listeners and routing rules
- [x] Configure SSL/TLS certificates (ACM)

#### 3.6 Additional Resources

- [x] Create S3 bucket for audio uploads (optional)
- [x] Create CloudWatch Log Groups
- [x] Configure IAM policies for cross-service communication
- [x] Set up CloudWatch dashboards

#### 3.7 Terraform Testing

- [x] Run `terraform init`
- [x] Run `terraform plan`
- [x] Validate all resource configurations
- [x] Document terraform outputs (endpoints, URLs)

---

### Phase 4: API Development

**Goal**: Build API service that interfaces with SageMaker

#### 4.1 API Setup (Golang)

- [x] Initialize project (go mod init)
- [x] Set up project structure (routes, handlers, middleware)
- [x] Configure environment variables
- [x] Set up logging framework

#### 4.2 Core API Endpoints

- [x] **POST /transcribe** - Accept audio file and return transcription
  - [x] Validate audio format (mp3, wav, m4a, etc.)
  - [x] Validate file size limits
  - [x] Handle multipart/form-data uploads
- [x] **GET /health** - Health check endpoint
- [x] **GET /status/:jobId** - Check transcription status (if async)

#### 4.3 SageMaker Integration

- [x] Install AWS SDK (aws-sdk-go or @aws-sdk/client-sagemaker-runtime)
- [x] Implement SageMaker InvokeEndpoint calls
- [x] Handle audio preprocessing (encoding, format conversion)
- [x] Parse and format SageMaker responses
- [ ] Implement retry logic and error handling
- [ ] Add request timeout handling

#### 4.4 Additional Features

- [ ] Implement rate limiting
- [x] Add CORS configuration
- [ ] Implement authentication/API keys (optional)
- [x] Add request logging and metrics
- [ ] Implement caching for repeated requests (optional)

#### 4.5 Testing & Containerization

- [ ] Write unit tests for handlers
- [ ] Write integration tests for SageMaker calls
- [x] Create Dockerfile for API
- [x] Build and test Docker image locally
- [x] Push image to ECR

---

### Phase 5: Frontend Development

**Goal**: Build Next.js application for user interaction

#### 5.1 Next.js Project Setup

- [x] Initialize Next.js project with TypeScript
- [x] Install dependencies (react, next, tailwind, etc.)
- [x] Configure SSR settings
- [x] Set up environment variables

#### 5.2 UI Components

- [x] Create landing page
- [x] Build audio upload component
  - [x] Drag-and-drop file upload
  - [x] File format validation
  - [x] Upload progress indicator
- [ ] Build audio recorder component (optional)
- [x] Create transcription results display
- [x] Add loading states and error handling
- [x] Implement responsive design

#### 5.3 API Integration

- [x] Create API client service
- [x] Implement file upload to API endpoint
- [x] Handle transcription responses
- [x] Display real-time status updates
- [x] Add error handling and user feedback

#### 5.4 Additional Features

- [x] Add download transcription feature (JSON, TXT)
- [ ] Implement transcription history (optional)
- [ ] Add audio playback with timestamp highlighting (optional)
- [ ] Create settings/configuration page

#### 5.5 Testing & Containerization

- [x] Test SSR functionality
- [x] Test client-side interactions
- [x] Create Dockerfile for Next.js app
- [x] Optimize build for production
- [x] Build and test Docker image locally
- [x] Push image to ECR

---

### Phase 6: Deployment

**Goal**: Deploy all components to AWS

#### 6.1 Initial Terraform Deployment

- [x] Run `terraform apply` to create infrastructure
- [x] Verify VPC and networking resources
- [x] Verify ECR repositories created
- [x] Document all created resource IDs

#### 6.2 Deploy SageMaker Model

- [x] Ensure model artifacts are in S3
- [x] Apply SageMaker terraform resources
- [x] Wait for endpoint to be InService
- [x] Test endpoint with AWS CLI/SDK
- [x] Verify endpoint metrics in CloudWatch

#### 6.3 Deploy API Service

- [x] Build API Docker image
- [x] Tag and push to ECR
- [x] Apply ECS terraform for API service
- [x] Verify ECS tasks are running
- [x] Test API health endpoint
- [x] Test /transcribe endpoint with sample audio

#### 6.4 Deploy Frontend Service

- [x] Build Frontend Docker image
- [x] Tag and push to ECR
- [x] Apply ECS terraform for Frontend service
- [x] Verify ECS tasks are running
- [x] Test frontend via ALB URL
- [ ] Verify SSR is working

#### 6.5 Configure Load Balancer

- [x] Verify ALB routing rules
- [x] Test API routes through ALB
- [x] Test frontend routes through ALB
- [ ] Configure custom domain (optional)
- [ ] Set up SSL certificate

---

### Phase 7: Testing & Optimization

**Goal**: Ensure system reliability and performance

#### 7.1 Integration Testing

- [x] Test complete flow: upload → API → SageMaker → response (Note: SageMaker dependency issue identified)
- [ ] Test with various audio formats (mp3, wav, m4a, flac)
- [ ] Test with different audio lengths (short, medium, long)
- [x] Test error scenarios (invalid files, oversized files)
- [ ] Load test API endpoints
- [ ] Test concurrent requests

#### 7.2 Performance Optimization

- [x] Monitor SageMaker endpoint latency
- [ ] Optimize model instance type if needed
- [x] Implement auto-scaling for SageMaker
- [x] Configure ECS task auto-scaling
- [ ] Optimize Docker image sizes
- [ ] Implement API response caching

#### 7.3 Monitoring & Logging

- [x] Set up CloudWatch dashboards
- [x] Configure log aggregation
- [ ] Create alarms for:
  - [ ] SageMaker endpoint failures
  - [ ] ECS task failures
  - [ ] API error rates
  - [ ] High latency warnings
- [ ] Set up SNS notifications

#### 7.4 Cost Optimization

- [x] Review SageMaker instance pricing
- [x] Implement auto-scaling to scale down during low usage
- [x] Review ECS task sizing
- [ ] Set up AWS Cost Explorer tags

---

### Phase 8: Documentation & Maintenance

**Goal**: Document the system and establish maintenance procedures

#### 8.1 Technical Documentation

- [x] Document architecture diagram
- [ ] Document API specifications (OpenAPI/Swagger)
- [x] Create deployment runbook
- [x] Document environment variables
- [x] Create troubleshooting guide
- [x] Document scaling procedures

#### 8.2 User Documentation

- [x] Create user guide for frontend
- [x] Document supported audio formats
- [x] Create FAQ section
- [x] Document any limitations (file size, duration)

#### 8.3 Maintenance Procedures

- [x] Establish backup procedures
- [x] Create disaster recovery plan
- [x] Document update/rollback procedures
- [ ] Set up security scanning (Snyk, Trivy)
- [x] Establish monitoring checklist

---

## Key Considerations

### SageMaker Instance Selection

- **ml.g4dn.xlarge**: ~$0.736/hour - Good for development
- **ml.g5.xlarge**: ~$1.408/hour - Better GPU performance
- **ml.m5.xlarge**: ~$0.269/hour - CPU-only (slower but cheaper)

### Audio Processing

- Max file size: Consider 25MB-100MB limit
- Supported formats: MP3, WAV, M4A, FLAC, OGG
- Consider async processing for files >10 minutes

### Security Best Practices

- [ ] Enable VPC endpoints for SageMaker
- [ ] Use IAM roles, not access keys
- [ ] Enable encryption at rest (S3, ECS)
- [ ] Enable encryption in transit (TLS/SSL)
- [ ] Implement API authentication
- [ ] Enable CloudTrail logging

### Estimated Timeline

- Phase 1: 1-2 days
- Phase 2: 2-3 days
- Phase 3: 3-4 days
- Phase 4: 3-5 days
- Phase 5: 4-6 days
- Phase 6: 2-3 days
- Phase 7: 2-3 days
- Phase 8: 1-2 days

**Total**: ~3-4 weeks for full implementation

---

## Success Criteria

- [ ] Whisper model successfully deployed on SageMaker
- [ ] API successfully communicates with SageMaker
- [ ] Frontend successfully uploads audio and displays transcriptions
- [ ] All infrastructure provisioned via Terraform
- [ ] System handles concurrent requests
- [ ] Monitoring and alerting functional
- [ ] Documentation complete

---

## Next Steps

1. Complete Phase 1 setup
2. Proceed through phases sequentially
3. Test thoroughly at each phase
4. Document issues and solutions as you encounter them
