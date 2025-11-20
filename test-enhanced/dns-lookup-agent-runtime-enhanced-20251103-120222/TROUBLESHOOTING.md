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
