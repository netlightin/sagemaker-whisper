# Troubleshooting Guide

## Table of Contents

1. [SageMaker Endpoint Issues](#sagemaker-endpoint-issues)
2. [ECS Service Issues](#ecs-service-issues)
3. [API Issues](#api-issues)
4. [Frontend Issues](#frontend-issues)
5. [Networking Issues](#networking-issues)
6. [Terraform Issues](#terraform-issues)
7. [Performance Issues](#performance-issues)

## SageMaker Endpoint Issues

### Issue: Endpoint Status is "Failed"

**Symptoms**:
```bash
$ aws sagemaker describe-endpoint --endpoint-name whisper-sagemaker-whisper-endpoint --region eu-west-1
EndpointStatus: Failed
FailureReason: ...
```

**Common Causes**:

1. **Model artifact not found in S3**
   ```bash
   # Check if model exists
   aws s3 ls s3://sagemaker-whisper-models-ACCOUNT_ID-REGION/whisper-large-v3-turbo/model.tar.gz
   ```
   **Solution**: Re-upload model using the packaging script
   ```bash
   cd ml-model
   python scripts/download_and_package_model.py --s3-bucket BUCKET_NAME
   ```

2. **Insufficient IAM permissions**
   - Check SageMaker execution role has S3 read access
   - Verify VPC endpoints for S3 are configured

3. **VPC configuration issues**
   - Ensure S3 VPC Gateway endpoint exists
   - Check security group rules allow outbound traffic

**Fix**:
```bash
# Delete failed endpoint
terraform destroy -target=module.sagemaker.aws_sagemaker_endpoint.whisper

# Fix underlying issue (model, IAM, VPC)

# Recreate endpoint
terraform apply -target=module.sagemaker.aws_sagemaker_endpoint.whisper
```

### Issue: "Numpy is not available" Error

**Symptoms**:
```
RuntimeError: Numpy is not available
```

**Root Cause**: PyTorch/HuggingFace container dependency issue

**Current Status**: Known issue - model inference fails

**Workarounds**:
1. Use custom Docker container with dependencies pre-installed
2. Modify inference.py to handle numpy differently
3. Use different base container image

**Long-term Solution**: Repackage model with proper dependency management

### Issue: Slow Cold Start (>60 seconds)

**Symptoms**: First request takes very long

**Cause**: Model loading time (~30-60s) + container initialization

**Solutions**:
1. Keep endpoint warm with scheduled invocations
   ```bash
   # Create EventBridge rule to invoke every 5 minutes
   aws events put-rule \
     --name keep-whisper-warm \
     --schedule-expression "rate(5 minutes)"
   ```

2. Use Provisioned Concurrency (if supported)

3. Optimize model loading in inference.py

### Issue: High Latency

**Symptoms**: Requests taking >10 seconds

**Diagnosis**:
```bash
# Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/SageMaker \
  --metric-name ModelLatency \
  --dimensions Name=EndpointName,Value=whisper-sagemaker-whisper-endpoint \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum \
  --region eu-west-1
```

**Solutions**:
1. Scale up to more instances
2. Upgrade instance type (ml.g5.xlarge for better GPU)
3. Optimize audio preprocessing
4. Reduce audio file size before sending

## ECS Service Issues

### Issue: Tasks Keep Failing/Restarting

**Symptoms**:
```bash
$ aws ecs describe-services ...
runningCount: 0
desiredCount: 2
```

**Diagnosis**:
```bash
# Check service events
aws ecs describe-services \
  --cluster whisper-sagemaker-cluster \
  --services whisper-sagemaker-api-service \
  --region eu-west-1 \
  --query 'services[0].events[0:10]'

# Check task logs
aws logs tail /ecs/whisper-sagemaker \
  --follow \
  --filter-pattern "ERROR" \
  --region eu-west-1
```

**Common Causes**:

1. **Health check failing**
   - Application not starting on expected port
   - Health endpoint returning errors

   **Solution**: Check application logs for startup errors

2. **Image pull errors**
   ```bash
   # Verify image exists
   aws ecr describe-images \
     --repository-name whisper-sagemaker-api \
     --region eu-west-1
   ```

   **Solution**: Rebuild and push image

3. **Insufficient CPU/Memory**
   - Container getting OOMKilled

   **Solution**: Increase task definition memory/CPU

4. **Environment variable issues**
   - Missing required variables
   - Incorrect SageMaker endpoint name

   **Solution**: Verify task definition environment variables

### Issue: Tasks Not Registering with ALB

**Symptoms**: ALB target health shows "unhealthy"

**Diagnosis**:
```bash
aws elbv2 describe-target-health \
  --target-group-arn ARN \
  --region eu-west-1
```

**Causes**:
1. Security group not allowing ALB → ECS traffic
2. Container not listening on correct port
3. Health check path incorrect

**Solution**:
```bash
# Check security group rules
aws ec2 describe-security-groups \
  --group-ids sg-XXXXX \
  --region eu-west-1

# Verify container port mapping in task definition
aws ecs describe-task-definition \
  --task-definition whisper-sagemaker-api \
  --region eu-west-1 \
  --query 'taskDefinition.containerDefinitions[0].portMappings'
```

## API Issues

### Issue: 502 Bad Gateway from ALB

**Symptoms**: Frontend shows 502 error

**Causes**:
1. API service not running
2. API returning errors
3. Timeout (ALB → API)

**Diagnosis**:
```bash
# Check ECS task count
aws ecs describe-services \
  --cluster whisper-sagemaker-cluster \
  --services whisper-sagemaker-api-service \
  --region eu-west-1 \
  --query 'services[0].{Running:runningCount,Desired:desiredCount}'

# Check API logs
aws logs tail /ecs/whisper-sagemaker \
  --follow \
  --filter-pattern "api" \
  --region eu-west-1
```

### Issue: "Failed to parse form data" Error

**Symptoms**: POST to /transcribe returns 400

**Cause**: Missing or incorrect Content-Type header

**Solution**: Ensure request uses `multipart/form-data`:
```bash
curl -X POST http://ALB_URL/transcribe \
  -F "audio=@file.wav"
```

### Issue: "Unsupported audio format" Error

**Symptoms**: API rejects file

**Cause**: File extension not in allowed list

**Allowed Formats**: .mp3, .wav, .m4a, .flac, .ogg, .webm

**Solution**: Convert file to supported format or update API validation

### Issue: SageMaker Invocation Timeout

**Symptoms**: Request takes >2 minutes then fails

**Causes**:
1. Audio file too long
2. SageMaker endpoint overloaded
3. Cold start delay

**Solutions**:
1. Implement async processing for long files
2. Scale SageMaker endpoint
3. Add request queuing

## Frontend Issues

### Issue: Frontend Shows Blank Page

**Symptoms**: Browser shows empty page, no errors

**Diagnosis**:
```bash
# Check browser console for errors
# Check if frontend service is running

aws ecs describe-services \
  --cluster whisper-sagemaker-cluster \
  --services whisper-sagemaker-frontend-service \
  --region eu-west-1
```

**Common Causes**:
1. Next.js build error
2. Missing environment variables
3. API_URL incorrect

**Solution**:
```bash
# Check frontend logs
aws logs tail /ecs/whisper-sagemaker \
  --follow \
  --filter-pattern "frontend" \
  --region eu-west-1

# Verify environment variables in task definition
aws ecs describe-task-definition \
  --task-definition whisper-sagemaker-frontend \
  --region eu-west-1 \
  --query 'taskDefinition.containerDefinitions[0].environment'
```

### Issue: Upload Button Not Working

**Symptoms**: File select works but upload fails

**Diagnosis**: Check browser Network tab for failed requests

**Common Causes**:
1. CORS error (check API logs)
2. File size exceeds limit (100MB default)
3. Network timeout

**Solutions**:
1. Verify CORS configuration in API
2. Reduce file size or increase limit
3. Check ALB timeout settings

## Networking Issues

### Issue: Cannot Access Application via ALB URL

**Symptoms**: Connection timeout or refused

**Diagnosis**:
```bash
# Check ALB exists and is active
aws elbv2 describe-load-balancers \
  --names whisper-sagemaker-alb \
  --region eu-west-1

# Check security group
aws ec2 describe-security-groups \
  --group-ids sg-XXXXX \
  --region eu-west-1 \
  --query 'SecurityGroups[0].IpPermissions'
```

**Solutions**:
1. Verify ALB security group allows inbound port 80
2. Check ALB is in public subnets
3. Verify target groups have healthy targets

### Issue: SageMaker Cannot Download Model from S3

**Symptoms**: Endpoint fails with S3 access error

**Cause**: Missing S3 VPC endpoint or incorrect security group

**Solution**:
```bash
# Check S3 VPC endpoint exists
aws ec2 describe-vpc-endpoints \
  --region eu-west-1 \
  --filters Name=vpc-id,Values=vpc-XXXXX

# Verify route tables include S3 endpoint
aws ec2 describe-route-tables \
  --region eu-west-1 \
  --filters Name=vpc-id,Values=vpc-XXXXX
```

## Terraform Issues

### Issue: "Resource Already Exists" Error

**Symptoms**:
```
Error: creating ECR Repository: RepositoryAlreadyExistsException
```

**Solution**: Import existing resource
```bash
terraform import module.ecr_api.aws_ecr_repository.this whisper-sagemaker-api
```

### Issue: State Lock Error

**Symptoms**:
```
Error: Error acquiring the state lock
```

**Solution**:
```bash
# If using S3 backend with DynamoDB locking
# Remove stale lock (only if you're sure no other terraform is running)
aws dynamodb delete-item \
  --table-name terraform-locks \
  --key '{"LockID":{"S":"LOCK_ID"}}'

# Or use force-unlock
terraform force-unlock LOCK_ID
```

### Issue: Endpoint Creation Timeout

**Symptoms**: Terraform times out waiting for endpoint

**Cause**: SageMaker endpoint takes >20 minutes to create

**Solution**: Increase timeout in terraform
```hcl
# In modules/sagemaker/main.tf
resource "aws_sagemaker_endpoint" "whisper" {
  # ...
  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}
```

## Performance Issues

### Issue: High API Response Time

**Symptoms**: Requests take >30 seconds

**Diagnosis**:
```bash
# Test API directly
time curl -X POST http://ALB_URL/transcribe -F "audio=@test.wav"

# Check CloudWatch metrics for bottleneck
```

**Solutions**:
1. Scale ECS tasks
2. Optimize API code
3. Implement caching
4. Use async processing

### Issue: High AWS Costs

**Symptoms**: Unexpected billing

**Diagnosis**:
```bash
# Check running resources
aws ecs list-tasks \
  --cluster whisper-sagemaker-cluster \
  --region eu-west-1

aws sagemaker list-endpoints \
  --region eu-west-1

# Review Cost Explorer in AWS Console
```

**Cost Reduction**:
1. Stop SageMaker endpoint when not in use
   ```bash
   terraform destroy -target=module.sagemaker.aws_sagemaker_endpoint.whisper
   ```

2. Scale down ECS services
   ```bash
   aws ecs update-service \
     --cluster whisper-sagemaker-cluster \
     --service whisper-sagemaker-api-service \
     --desired-count 1
   ```

3. Use spot instances (non-production)

4. Delete unused resources

## Getting Help

### Check Logs

```bash
# Comprehensive log check
./check-logs.sh

# ECS logs
aws logs tail /ecs/whisper-sagemaker --follow --region eu-west-1

# SageMaker logs
aws logs tail /aws/sagemaker/Endpoints/whisper-sagemaker-whisper-endpoint --follow --region eu-west-1
```

### Check Resource Status

```bash
# Quick status check
./check-status.sh

# Detailed service info
aws ecs describe-services \
  --cluster whisper-sagemaker-cluster \
  --services whisper-sagemaker-api-service whisper-sagemaker-frontend-service \
  --region eu-west-1

# SageMaker endpoint
aws sagemaker describe-endpoint \
  --endpoint-name whisper-sagemaker-whisper-endpoint \
  --region eu-west-1
```

### Debug Checklist

- [ ] Check CloudWatch logs for errors
- [ ] Verify all ECS services are running
- [ ] Confirm SageMaker endpoint is InService
- [ ] Test ALB health checks
- [ ] Verify security group rules
- [ ] Check IAM role permissions
- [ ] Review recent deployments/changes
- [ ] Check AWS Service Health Dashboard
- [ ] Verify resource quotas not exceeded

### Escalation

If issues persist:

1. Review AWS CloudTrail for API errors
2. Enable VPC Flow Logs for network debugging
3. Contact AWS Support (if applicable)
4. Check project GitHub issues
5. Review AWS Service Health Dashboard for region issues

## Useful Commands

```bash
# Quick restart of all services
terraform apply -target=module.ecs

# Force new ECS deployment
aws ecs update-service \
  --cluster whisper-sagemaker-cluster \
  --service whisper-sagemaker-api-service \
  --force-new-deployment \
  --region eu-west-1

# View all CloudWatch log streams
aws logs describe-log-streams \
  --log-group-name /ecs/whisper-sagemaker \
  --region eu-west-1

# Get recent errors from logs
aws logs filter-log-events \
  --log-group-name /ecs/whisper-sagemaker \
  --filter-pattern "ERROR" \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --region eu-west-1
```
