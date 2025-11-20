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
