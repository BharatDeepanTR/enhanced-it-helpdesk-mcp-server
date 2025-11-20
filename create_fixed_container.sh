#!/bin/bash
"""
Script to create a fixed version of the DNS container with correct SSM path
"""

# Create a temporary directory for the fix
mkdir -p /tmp/dns-fix
cd /tmp/dns-fix

# Extract files from the original container
echo "Extracting files from original container..."
docker run --rm --entrypoint sh 818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.0.0 -c "cd /app && tar -czf - ." | tar -xzf -

# Create a patched version of chatops_helpers.py
echo "Creating patched version..."
cat > chatops_helpers_patch.py << 'EOF'
import os
# Patch the get_ssm_secrets function to use the correct path
original_get_ssm_secrets = None

def patch_get_ssm_secrets():
    """Patch to use correct SSM path"""
    import chatops_helpers
    global original_get_ssm_secrets
    
    if original_get_ssm_secrets is None:
        original_get_ssm_secrets = chatops_helpers.get_ssm_secrets
        
    def patched_get_ssm_secrets():
        # Override environment variables to point to correct SSM path
        os.environ['ENV'] = 'dev'
        os.environ['APP_CONFIG_PATH'] = '/a208194/APISECRETS'
        return original_get_ssm_secrets()
    
    chatops_helpers.get_ssm_secrets = patched_get_ssm_secrets

# Apply the patch when this module is imported
patch_get_ssm_secrets()
EOF

# Create a patched container_handler.py
echo "Patching container handler..."
sed '1i import chatops_helpers_patch  # Apply SSM path fix' container_handler.py > container_handler_patched.py
mv container_handler_patched.py container_handler.py

# Create Dockerfile for the fixed version
cat > Dockerfile << 'EOF'
FROM 818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.0.0

# Copy the patched files
COPY chatops_helpers_patch.py /app/
COPY container_handler.py /app/

# Set the correct environment variables as defaults
ENV ENV=dev
ENV APP_CONFIG_PATH=/a208194/APISECRETS
ENV AWS_DEFAULT_REGION=us-east-1

WORKDIR /app
EOF

echo "Building fixed container..."
docker build -t 818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.0.1-fixed .

echo "Tagging for ECR..."
docker tag 818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.0.1-fixed 818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.0.1-fixed

echo "Fixed container created: dns-lookup-service:v1.0.1-fixed"
echo "Next: Push to ECR and update Agent Core Runtime source"