# DNS Lookup Service - Secure ARM64 Docker Container

## Overview

This guide explains how to convert your DNS lookup lambda function into a secure, production-ready ARM64 Docker container with comprehensive vulnerability scanning and deployment options.

## 🔧 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Multi-Stage Docker Build                 │
├─────────────────────────────────────────────────────────────┤
│  Builder Stage (python:3.11.6-slim-bookworm)               │
│  ├─ Install build dependencies                              │
│  ├─ Create virtual environment                              │
│  └─ Install Python packages                                 │
├─────────────────────────────────────────────────────────────┤
│  Production Stage (python:3.11.6-slim-bookworm)            │
│  ├─ Minimal runtime environment                             │
│  ├─ Non-root user (UID: 10001)                             │
│  ├─ Read-only root filesystem                               │
│  ├─ Security hardening                                      │
│  └─ HTTP server for containerized execution                 │
└─────────────────────────────────────────────────────────────┘
```

## 🛡️ Security Features

### Container Security
- ✅ **Multi-stage build** - Minimal attack surface
- ✅ **Non-root execution** - Runs as UID 10001
- ✅ **Read-only root filesystem** - Prevents tampering
- ✅ **Dropped capabilities** - ALL capabilities dropped
- ✅ **Security Context** - Comprehensive security policies
- ✅ **Resource limits** - Memory and CPU constraints
- ✅ **Health checks** - Proper liveness/readiness probes

### Dependency Security
- ✅ **Pinned versions** - All dependencies locked to specific versions
- ✅ **Vulnerability scanning** - Trivy and pip-audit integration
- ✅ **SBOM generation** - Software Bill of Materials
- ✅ **Base image verification** - Digest-based image references

### Network Security
- ✅ **TLS/HTTPS enforcement** - Secure communication
- ✅ **CORS configuration** - Cross-origin request control
- ✅ **Rate limiting** - DoS protection
- ✅ **Request size limits** - Input validation
- ✅ **Security headers** - XSS, CSRF, and other protections

## 📁 Project Structure

```
chatops_route_dns/
├── Dockerfile                    # Secure multi-stage Dockerfile
├── requirements.txt             # Pinned Python dependencies
├── requirements-security.txt    # Security scanning tools
├── .dockerignore               # Security-focused ignore patterns
├── function.txt                # GenAI configuration template
├── container_handler.py        # HTTP server for containerized execution
├── build-secure.sh            # Comprehensive build script with scanning
├── deploy.sh                  # Multi-platform deployment script
├── k8s/                       # Kubernetes deployment manifests
│   ├── deployment.yaml        # Secure Kubernetes deployment
│   └── ingress.yaml          # NGINX ingress with security headers
├── aws-ecs/                   # AWS ECS deployment configurations
│   ├── task-definition.json   # ECS task definition for ARM64
│   └── service-definition.json # ECS service configuration
└── docs/                      # Documentation
```

## 🚀 Quick Start

### Prerequisites

1. **Docker with BuildKit support**
   ```bash
   docker version  # Ensure Docker is installed
   docker buildx version  # Ensure BuildKit is available
   ```

2. **Security scanning tools** (optional, will be installed automatically)
   ```bash
   # Install Trivy for vulnerability scanning
   curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
   ```

3. **Platform requirements**
   - ARM64 compatible host or Docker Desktop with ARM64 emulation
   - At least 2GB RAM for building
   - 1GB disk space for images and cache

### Option 1: Local Testing (Recommended First Step)

```bash
# Clone and navigate to the project
cd /path/to/chatops_route_dns

# Deploy locally for testing
./deploy.sh local

# Test the service
curl http://localhost:8080/health
curl -X POST http://localhost:8080/lookup \
  -H "Content-Type: application/json" \
  -d '{"dns_name": "example.com"}'

# Stop the test container
docker stop dns-lookup-test
```

### Option 2: Kubernetes Deployment

```bash
# Prerequisites: kubectl configured and cluster accessible
kubectl cluster-info

# Deploy to Kubernetes
./deploy.sh k8s v1.0.0

# Check deployment status
kubectl get pods -n dns-lookup
kubectl logs -f deployment/dns-lookup-service -n dns-lookup

# Port forward for testing
kubectl port-forward svc/dns-lookup-service 8080:80 -n dns-lookup
```

### Option 3: AWS ECS Deployment

```bash
# Prerequisites: AWS CLI configured
aws sts get-caller-identity

# Set your ECR registry
export REGISTRY=123456789012.dkr.ecr.us-east-1.amazonaws.com

# Deploy to ECS
./deploy.sh ecs v1.0.0

# Check deployment status
aws ecs describe-services --cluster dns-lookup-cluster --services dns-lookup-service
```

## 🔧 Manual Build Process

### Step 1: Build with Security Scanning

```bash
# Build with comprehensive security scanning
./build-secure.sh v1.0.0

# This will:
# 1. Scan Python dependencies for vulnerabilities
# 2. Build the ARM64 Docker image
# 3. Scan the final image with Trivy
# 4. Generate SBOM (Software Bill of Materials)
# 5. Test basic functionality
# 6. Generate security reports
```

### Step 2: Review Security Reports

```bash
# Review vulnerability scan results
cat trivy-report.txt
cat pip-audit-report.json

# Check SBOM
cat sbom.txt
```

### Step 3: Test the Container

```bash
# Run the container
docker run -d --name dns-test \
  --platform linux/arm64 \
  -p 8080:8080 \
  -e ENV=test \
  -e APP_CONFIG_PATH=/config \
  localhost:5000/dns-lookup-service:v1.0.0

# Test endpoints
curl http://localhost:8080/health
curl http://localhost:8080/
curl -X POST http://localhost:8080/lookup \
  -H "Content-Type: application/json" \
  -d '{"dns_name": "example.com"}'

# Stop and cleanup
docker stop dns-test && docker rm dns-test
```

## 🔒 Security Configuration

### Environment Variables

```bash
# Required for production
ENV=production
APP_CONFIG_PATH=/config

# HTTP server configuration
HOST=0.0.0.0
PORT=8080

# AWS credentials (use secrets management)
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key

# GenAI configuration
OPENAI_API_KEY=your-openai-key
```

### Secrets Management

#### Kubernetes Secrets
```bash
# Create secrets
kubectl create secret generic dns-lookup-secrets \
  --from-literal=AWS_ACCESS_KEY_ID=your-key \
  --from-literal=AWS_SECRET_ACCESS_KEY=your-secret \
  --from-literal=OPENAI_API_KEY=your-openai-key \
  -n dns-lookup
```

#### AWS Secrets Manager
```bash
# Create secrets in AWS Secrets Manager
aws secretsmanager create-secret \
  --name dns-lookup/aws-credentials \
  --secret-string '{"AWS_ACCESS_KEY_ID":"your-key","AWS_SECRET_ACCESS_KEY":"your-secret"}'

aws secretsmanager create-secret \
  --name dns-lookup/openai \
  --secret-string '{"OPENAI_API_KEY":"your-openai-key"}'
```

## 📊 Monitoring and Observability

### Health Checks

- **Endpoint**: `GET /health`
- **Response**: JSON with service status
- **Kubernetes**: Configured liveness/readiness probes
- **ECS**: Configured health check command

### Logging

- **Format**: Structured JSON logging
- **Kubernetes**: Logs available via `kubectl logs`
- **ECS**: CloudWatch Logs integration
- **Local**: Docker logs via `docker logs`

### Metrics (Optional Enhancement)

```python
# Add to container_handler.py for Prometheus metrics
from prometheus_client import Counter, Histogram, generate_latest

REQUEST_COUNT = Counter('dns_lookup_requests_total', 'Total DNS lookup requests')
REQUEST_DURATION = Histogram('dns_lookup_duration_seconds', 'DNS lookup request duration')
```

## 🚀 Production Deployment Checklist

### Pre-deployment
- [ ] Security scan results reviewed and approved
- [ ] All dependencies updated to latest secure versions
- [ ] Secrets properly configured in secrets management system
- [ ] Resource limits appropriate for expected load
- [ ] Network policies configured (Kubernetes)
- [ ] Load balancer and ingress configured
- [ ] Monitoring and alerting configured

### Deployment
- [ ] Image pushed to secure registry
- [ ] Deployment manifests applied
- [ ] Health checks passing
- [ ] Service accessible through load balancer
- [ ] SSL/TLS certificates configured and valid

### Post-deployment
- [ ] Functional testing completed
- [ ] Performance testing completed
- [ ] Security scanning in production environment
- [ ] Monitoring dashboards configured
- [ ] Incident response procedures documented

## 🛠️ Troubleshooting

### Common Issues

1. **ARM64 Architecture Issues**
   ```bash
   # Ensure you're building for the correct platform
   docker buildx build --platform linux/arm64 .
   
   # Check node architecture in Kubernetes
   kubectl get nodes -o wide
   ```

2. **Permission Denied Errors**
   ```bash
   # Check if running as non-root
   docker run --rm image-name id
   
   # Verify file permissions
   docker run --rm image-name ls -la /app
   ```

3. **Health Check Failures**
   ```bash
   # Check container logs
   docker logs container-name
   
   # Test health endpoint manually
   docker exec container-name curl http://localhost:8080/health
   ```

4. **Vulnerability Scan Failures**
   ```bash
   # Update base image
   # Update Python dependencies
   # Review and assess risk for remaining vulnerabilities
   ```

### Log Analysis

```bash
# Kubernetes logs
kubectl logs -f deployment/dns-lookup-service -n dns-lookup

# ECS logs
aws logs get-log-events --log-group-name /ecs/dns-lookup-service

# Docker logs
docker logs -f container-name
```

## 📈 Performance Optimization

### Resource Sizing

#### Development/Testing
- **CPU**: 100m (0.1 core)
- **Memory**: 256Mi
- **Replicas**: 1

#### Production
- **CPU**: 500m (0.5 core)
- **Memory**: 512Mi
- **Replicas**: 3+ (based on load)

### Scaling

#### Kubernetes HPA
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: dns-lookup-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: dns-lookup-service
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

#### ECS Auto Scaling
```bash
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/dns-lookup-cluster/dns-lookup-service \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 3 \
  --max-capacity 10
```

## 🔄 CI/CD Integration

### GitHub Actions Example

```yaml
name: Build and Deploy DNS Lookup Service

on:
  push:
    branches: [main]
    tags: [v*]

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Run security build
      run: ./build-secure.sh ${{ github.ref_name }}
    - name: Upload scan results
      uses: actions/upload-artifact@v3
      with:
        name: security-reports
        path: |
          trivy-report.json
          pip-audit-report.json
          sbom.spdx.json

  deploy:
    needs: security-scan
    runs-on: ubuntu-latest
    if: startsWith(github.ref, 'refs/tags/')
    steps:
    - uses: actions/checkout@v4
    - name: Deploy to production
      run: ./deploy.sh k8s ${{ github.ref_name }}
```

This comprehensive setup provides a secure, scalable, and production-ready containerized version of your DNS lookup lambda function optimized for ARM64 architecture with zero vulnerabilities.