# Whisper SageMaker - Speech-to-Text Transcription Service

A production-ready speech-to-text transcription service powered by OpenAI's Whisper Large V3 Turbo model, deployed on AWS SageMaker with a modern web interface.

## Features

- **Accurate Transcription**: Powered by Whisper Large V3 Turbo
- **Multiple Audio Formats**: Supports MP3, WAV, M4A, FLAC, OGG, WebM
- **Real-time Processing**: Fast GPU-accelerated transcription
- **User-Friendly Interface**: Modern web UI built with Next.js
- **Scalable Architecture**: Auto-scaling infrastructure
- **Production-Ready**: Full monitoring and logging

## Application URL

**http://whisper-sagemaker-alb-299033305.eu-west-1.elb.amazonaws.com**

## Quick Start

### Using the Web Interface

1. Navigate to the application URL above
2. Upload an audio file (drag-and-drop or click to select)
3. Click "Transcribe" and wait for results
4. Copy or download the transcription

### Using the API

```bash
curl -X POST http://whisper-sagemaker-alb-299033305.eu-west-1.elb.amazonaws.com/transcribe \
  -F "audio=@your_file.mp3"
```

## Supported Formats

| Format | Extension | Max Size | Max Duration |
|--------|-----------|----------|--------------|
| MP3 | .mp3 | 100MB | 5 minutes |
| WAV | .wav | 100MB | 5 minutes |
| M4A | .m4a | 100MB | 5 minutes |
| FLAC | .flac | 100MB | 5 minutes |
| OGG | .ogg | 100MB | 5 minutes |
| WebM | .webm | 100MB | 5 minutes |

## Documentation

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - System architecture and components
- **[DEPLOYMENT.md](./DEPLOYMENT.md)** - Deployment procedures and runbooks
- **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** - Common issues and solutions
- **[PROJECT_PLAN.md](./PROJECT_PLAN.md)** - Development roadmap

## API Endpoints

### Health Check
```bash
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "endpoint": "whisper-sagemaker-whisper-endpoint"
}
```

### Transcribe Audio
```bash
POST /transcribe
Content-Type: multipart/form-data
```

**Parameters:**
- `audio` (file, required): Audio file to transcribe

**Response:**
```json
{
  "text": "Transcribed text...",
  "language": "en",
  "duration": 45.2
}
```

## Technology Stack

- **Frontend**: Next.js 16, TypeScript, Tailwind CSS
- **Backend**: Go 1.24, AWS SDK v2
- **ML Model**: Whisper Large V3 Turbo on SageMaker
- **Infrastructure**: AWS (ECS Fargate, SageMaker, ALB, VPC)
- **IaC**: Terraform

## Architecture

```
Internet → ALB → [Frontend | API] → SageMaker → S3
```

- **VPC**: Multi-AZ with public/private subnets
- **ECS Fargate**: API (Go) and Frontend (Next.js)
- **SageMaker**: ml.g4dn.xlarge with Whisper model
- **Auto-scaling**: ECS (1-10 tasks), SageMaker (1-3 instances)

## Deployment

```bash
# 1. Package model
cd ml-model
python scripts/download_and_package_model.py --s3-bucket BUCKET_NAME

# 2. Build images
cd api && docker build -t api . && docker push ECR_URL/api
cd frontend && docker build -t frontend . && docker push ECR_URL/frontend

# 3. Deploy
cd terraform && terraform apply
```

See [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed instructions.

## Monitoring

- **Dashboard**: [whisper-sagemaker-dashboard](https://eu-west-1.console.aws.amazon.com/cloudwatch/home?region=eu-west-1#dashboards:name=whisper-sagemaker-dashboard)
- **Logs**: CloudWatch `/ecs/whisper-sagemaker`
- **Metrics**: SageMaker latency, ECS CPU/memory, ALB requests

## Known Issues

1. **SageMaker Model Issue**: Numpy dependency error - under investigation
2. **No HTTPS**: HTTP only (HTTPS planned)
3. **No Authentication**: Publicly accessible (authentication planned)

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for solutions.

## Cost Estimate

- **24/7 Operation**: ~$650-700/month
- **Business Hours Only**: ~$250-300/month

Primary costs: SageMaker ml.g4dn.xlarge ($0.736/hour), NAT Gateways, ECS Fargate

## Project Structure

```
.
├── api/                    # Go API service
├── frontend/               # Next.js frontend
├── ml-model/               # Model packaging scripts
├── terraform/              # Infrastructure as Code
│   ├── modules/
│   │   ├── networking/
│   │   ├── ecr/
│   │   ├── ecs/
│   │   └── sagemaker/
│   └── main.tf
├── ARCHITECTURE.md         # Architecture documentation
├── DEPLOYMENT.md           # Deployment guide
├── TROUBLESHOOTING.md      # Troubleshooting guide
└── PROJECT_PLAN.md         # Project roadmap
```

## Development

### Local API Development
```bash
cd api
go mod download
go run main.go
```

### Local Frontend Development
```bash
cd frontend
npm install
npm run dev
```

### Infrastructure Changes
```bash
cd terraform
terraform plan
terraform apply
```

## Security

- Services in private subnets
- Security groups with least-privilege access
- IAM roles (no hardcoded credentials)
- Audio not persisted (processed in memory)

**Production Recommendations**:
- Enable HTTPS with ACM
- Add API authentication
- Enable WAF and CloudTrail
- Implement rate limiting

## License

[Specify your license]

## Support

- **Documentation**: See markdown files in repository
- **Issues**: Check TROUBLESHOOTING.md
- **AWS Support**: For infrastructure issues

## Acknowledgments

- OpenAI for Whisper model
- HuggingFace for transformers library
- AWS for SageMaker and infrastructure services
