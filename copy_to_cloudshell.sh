#!/bin/bash
# Copy essential files to CloudShell for DNS Agent container rebuild
# Run this from /mnt/c/Users/6135616/chatops_route_dns

echo "Copying essential DNS Agent files to CloudShell..."

# Critical files - these MUST be copied
cp chatops_route_dns_intent.py /home/bharat/
cp container_handler_mcp.py /home/bharat/
cp Dockerfile.simple /home/bharat/
cp chatops_helpers.py /home/bharat/
cp requirements.txt /home/bharat/

# Optional alternative handler
cp container_handler_stdin.py /home/bharat/

# Test files for validation
cp test_lambda_local.py /home/bharat/
cp debug_detailed.py /home/bharat/

echo "✅ Files copied successfully!"
echo ""
echo "Files copied to /home/bharat/:"
ls -la /home/bharat/*.py /home/bharat/Dockerfile.simple /home/bharat/requirements.txt

echo ""
echo "🚀 Next steps in CloudShell:"
echo "1. cd /home/cloudshell-user"
echo "2. Test locally: python3 test_lambda_local.py"
echo "3. Build container: docker build -t dns-lookup-service:v9.0.0-fixed-logic -f Dockerfile.simple ."
echo "4. Deploy to ECR and update Agent Core Runtime"