#!/bin/bash
# Create enhanced Cloud Shell package with Agent Core Runtime fixes
# Prevents "Unable to invoke endpoint successfully" errors

set -e

PACKAGE_NAME="dns-lookup-agent-runtime-enhanced-$(date +%Y%m%d-%H%M%S)"
PACKAGE_DIR="$PACKAGE_NAME"

echo "📦 Creating Enhanced Agent Core Runtime Package"
echo "=============================================="
echo "Package: $PACKAGE_NAME"
echo ""

# Create package directory
mkdir -p "$PACKAGE_DIR"

echo "🔄 Copying enhanced files..."

# Copy core application files
cp chatops_route_dns_intent.py "$PACKAGE_DIR/"
cp chatops_helpers.py "$PACKAGE_DIR/"
cp chatops_config.py "$PACKAGE_DIR/"
cp container_handler.py "$PACKAGE_DIR/"

# Copy enhanced Lambda handler
cp lambda_handler_fixed.py "$PACKAGE_DIR/lambda_handler.py"

# Copy enhanced Dockerfile with Lambda RIC
cp Dockerfile.agent-runtime-fixed "$PACKAGE_DIR/Dockerfile"

# Copy enhanced requirements
cp requirements-agent-runtime.txt "$PACKAGE_DIR/requirements.txt"

# Copy enhanced deployment script
cp deploy-enhanced.sh "$PACKAGE_DIR/deploy.sh"
chmod +x "$PACKAGE_DIR/deploy.sh"

# Copy support files
cp .dockerignore "$PACKAGE_DIR/" 2>/dev/null || echo "# Docker ignore file" > "$PACKAGE_DIR/.dockerignore"

# Create enhanced README
cat > "$PACKAGE_DIR/README.md" << 'EOF'
# DNS Lookup Service - Enhanced Agent Core Runtime

This package contains an enhanced version specifically designed to prevent 
"Unable to invoke endpoint successfully" errors in AWS Bedrock Agent Core Runtime.

## Key Enhancements

1. **Lambda Runtime Interface Client (RIC)**: Uses official AWS Lambda base image
2. **Enhanced Error Handling**: Comprehensive logging and error responses
3. **Multiple Input Formats**: Supports various Agent Core Runtime event formats
4. **Cloud Shell Optimized**: Works with temporary AWS credentials
5. **Multi-Architecture Support**: ARM64 + x86_64 with fallback strategies

## Deployment

```bash
# Extract package
tar -xzf dns-lookup-agent-runtime-enhanced-*.tar.gz
cd dns-lookup-agent-runtime-enhanced-*

# Deploy to ECR
chmod +x deploy.sh
./deploy.sh
```

## Agent Core Runtime Configuration

- **Image URI**: `${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.4.0`
- **Entry Point**: `lambda_handler.lambda_handler`
- **Memory**: 512 MB (minimum)
- **Timeout**: 30 seconds

## Testing

Input format: `{"domain": "google.com"}`

Test with:
- `{"domain": "google.com"}`
- `{"domain": "aws.amazon.com"}`
- `{"domain": "github.com"}`

## Troubleshooting

If you encounter "Unable to invoke endpoint successfully":
1. Check CloudWatch logs for detailed error messages
2. Verify the image URI is correct in Agent Core Runtime
3. Ensure the handler is set to `lambda_handler.lambda_handler`
4. Verify memory allocation is at least 512 MB
EOF

# Create troubleshooting guide
cat > "$PACKAGE_DIR/TROUBLESHOOTING.md" << 'EOF'
# Troubleshooting Guide - Agent Core Runtime

## Common Issues and Solutions

### "Unable to invoke endpoint successfully"

**Causes and Fixes:**

1. **Incorrect Handler Configuration**
   - Ensure handler is set to: `lambda_handler.lambda_handler`
   - Verify entry point in Dockerfile: `CMD ["lambda_handler.lambda_handler"]`

2. **Missing Lambda Runtime Interface Client**
   - This package uses `public.ecr.aws/lambda/python:3.11` base image
   - Includes `awslambdaric==2.0.8` in requirements

3. **Memory/Timeout Issues**
   - Set memory to at least 512 MB
   - Set timeout to at least 30 seconds
   - Monitor CloudWatch logs for memory usage

4. **Environment Variables**
   - Ensure ENV variable is set in Agent Core Runtime
   - Check AWS credentials are properly configured

5. **Input Format Issues**
   - Use: `{"domain": "example.com"}`
   - Avoid nested or complex event structures

### Container Build Issues

1. **Multi-arch Build Failures**
   - Script automatically falls back to single architecture
   - Both ARM64 and x86_64 are supported

2. **ECR Permission Issues**
   - Ensure IAM role has ECR push permissions
   - Check ECR repository policy

3. **Network Issues in Cloud Shell**
   - Retry the deployment if network timeouts occur
   - Script includes retry logic for common failures

### DNS Lookup Issues

1. **Route53 Access**
   - Verify cross-account role permissions
   - Check SSM parameters are configured

2. **Domain Resolution**
   - Test with known domains first (google.com, aws.amazon.com)
   - Verify domain exists and is resolvable

## CloudWatch Logs

Check these log groups for detailed error information:
- `/aws/lambda/your-agent-core-runtime-function`
- Look for "ERROR" and "WARN" level messages

## Support

If issues persist:
1. Check CloudWatch logs first
2. Verify all Agent Core Runtime configuration settings
3. Test with simple domains like "google.com"
4. Ensure the container image built and pushed successfully
EOF

# Create validation script for the package
cat > "$PACKAGE_DIR/validate-package.sh" << 'EOF'
#!/bin/bash
# Validate the enhanced package before deployment

echo "🔍 Validating Enhanced Agent Core Runtime Package"
echo "=============================================="

ERRORS=0

# Check required files
REQUIRED_FILES=(
    "Dockerfile"
    "deploy.sh"
    "lambda_handler.py"
    "requirements.txt"
    "chatops_route_dns_intent.py"
    "chatops_helpers.py"
    "chatops_config.py"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file missing"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check Dockerfile for Lambda base image
if grep -q "public.ecr.aws/lambda/python" Dockerfile; then
    echo "✅ Lambda base image configured"
else
    echo "❌ Lambda base image not found in Dockerfile"
    ERRORS=$((ERRORS + 1))
fi

# Check requirements for Lambda RIC
if grep -q "awslambdaric" requirements.txt; then
    echo "✅ Lambda Runtime Interface Client included"
else
    echo "❌ Lambda RIC missing from requirements"
    ERRORS=$((ERRORS + 1))
fi

# Check lambda handler
if grep -q "lambda_handler" lambda_handler.py; then
    echo "✅ Lambda handler function found"
else
    echo "❌ Lambda handler function missing"
    ERRORS=$((ERRORS + 1))
fi

# Check deploy script
if [ -x "deploy.sh" ]; then
    echo "✅ Deploy script executable"
else
    echo "❌ Deploy script not executable"
    ERRORS=$((ERRORS + 1))
fi

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "🎉 Package validation successful!"
    echo "Ready for Cloud Shell deployment."
else
    echo "❌ Package validation failed with $ERRORS errors."
    exit 1
fi
EOF

chmod +x "$PACKAGE_DIR/validate-package.sh"

# Create the compressed package
echo ""
echo "🗜️  Creating compressed package..."
tar -czf "${PACKAGE_NAME}.tar.gz" "$PACKAGE_DIR"

# Get package size
PACKAGE_SIZE=$(du -h "${PACKAGE_NAME}.tar.gz" | cut -f1)

echo ""
echo "✅ Enhanced Package Created Successfully!"
echo ""
echo "📦 Package Details:"
echo "   Name: ${PACKAGE_NAME}.tar.gz"
echo "   Size: $PACKAGE_SIZE"
echo "   Version: v1.4.0 (Enhanced)"
echo "   Features: Lambda RIC, Enhanced Error Handling, Multi-arch"
echo ""
echo "🚀 Deployment Instructions:"
echo "   1. Upload ${PACKAGE_NAME}.tar.gz to Cloud Shell"
echo "   2. tar -xzf ${PACKAGE_NAME}.tar.gz"
echo "   3. cd $PACKAGE_NAME"
echo "   4. ./validate-package.sh  # Optional validation"
echo "   5. ./deploy.sh           # Deploy to ECR"
echo ""
echo "🎯 Key Improvements to Prevent Endpoint Errors:"
echo "   ✅ AWS Lambda base image with Runtime Interface Client"
echo "   ✅ Enhanced error handling and logging"
echo "   ✅ Multiple input format support"
echo "   ✅ Proper Lambda handler configuration"
echo "   ✅ CloudWatch logging integration"
echo "   ✅ Memory and timeout optimizations"
echo ""
echo "💡 This enhanced version specifically addresses the"
echo "   'Unable to invoke endpoint successfully' error!"

# Cleanup
rm -rf "$PACKAGE_DIR"

echo ""
echo "📁 Package ready: ${PACKAGE_NAME}.tar.gz"