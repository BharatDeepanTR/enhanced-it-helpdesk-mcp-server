#!/bin/bash
"""
ECR Agent Source Code Extractor
===============================

This script pulls and extracts the DNS agent source code from ECR
to understand the agent's structure and expected prompt format.
"""

set -e

# Configuration
REGION="us-east-1"
ACCOUNT_ID="818565325759"
REPOSITORY_NAME="dns-lookup-service"
REPOSITORY_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPOSITORY_NAME}"
EXTRACT_DIR="./dns_agent_source"

echo "🔍 DNS Agent Source Code Extraction"
echo "===================================="
echo "📍 Region: $REGION"
echo "🏦 Account: $ACCOUNT_ID"
echo "📦 Repository: $REPOSITORY_NAME"
echo "🌐 Repository URI: $REPOSITORY_URI"
echo ""

# Create extraction directory
echo "📁 Creating extraction directory..."
mkdir -p "$EXTRACT_DIR"
cd "$EXTRACT_DIR"

# Authenticate Docker to ECR
echo "🔐 Authenticating Docker to ECR..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REPOSITORY_URI"

if [ $? -eq 0 ]; then
    echo "✅ ECR authentication successful"
else
    echo "❌ ECR authentication failed"
    exit 1
fi

# Get the latest image digest
echo "🔍 Finding latest image..."
LATEST_IMAGE=$(aws ecr describe-images \
    --repository-name "$REPOSITORY_NAME" \
    --region "$REGION" \
    --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageDigest' \
    --output text)

if [ "$LATEST_IMAGE" != "None" ] && [ "$LATEST_IMAGE" != "" ]; then
    echo "✅ Found latest image: $LATEST_IMAGE"
    IMAGE_TAG="$REPOSITORY_URI@$LATEST_IMAGE"
else
    echo "⚠️ No tagged images found, using latest"
    IMAGE_TAG="$REPOSITORY_URI:latest"
fi

echo "🐳 Image to pull: $IMAGE_TAG"

# Pull the Docker image
echo "⬇️ Pulling Docker image..."
docker pull "$IMAGE_TAG"

if [ $? -eq 0 ]; then
    echo "✅ Image pulled successfully"
else
    echo "❌ Failed to pull image"
    exit 1
fi

# Create a container from the image (don't run it)
echo "📦 Creating container to extract files..."
CONTAINER_ID=$(docker create "$IMAGE_TAG")

if [ $? -eq 0 ]; then
    echo "✅ Container created: $CONTAINER_ID"
else
    echo "❌ Failed to create container"
    exit 1
fi

# Extract files from container
echo "📤 Extracting source code from container..."

# Common paths where agent code might be located
EXTRACT_PATHS=(
    "/app"
    "/src"
    "/opt/app"
    "/usr/src/app"
    "/home/app"
    "/agent"
    "/dns-service"
    "/"
)

for path in "${EXTRACT_PATHS[@]}"; do
    echo "🔍 Checking path: $path"
    
    # Try to copy from this path
    docker cp "$CONTAINER_ID:$path" "./extracted_$path" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully extracted from: $path"
        
        # List contents
        echo "📋 Contents of $path:"
        find "./extracted_$path" -type f -name "*.py" -o -name "*.json" -o -name "*.md" -o -name "*.txt" -o -name "*.yaml" -o -name "*.yml" | head -20
        echo ""
    else
        echo "⚠️ No files found in: $path"
        rm -rf "./extracted_$path" 2>/dev/null
    fi
done

# Clean up container
echo "🧹 Cleaning up container..."
docker rm "$CONTAINER_ID" >/dev/null

echo ""
echo "🔍 ANALYSIS RESULTS"
echo "=================="

# Look for important files
echo "📄 Searching for important agent files..."

# Find all relevant files
find . -type f \( -name "*.py" -o -name "*.json" -o -name "*.md" -o -name "*.txt" -o -name "*.yaml" -o -name "*.yml" \) 2>/dev/null | while read file; do
    echo "📁 Found: $file"
    
    # Check for specific agent-related content
    if [[ "$file" =~ \.(py|json|yaml|yml)$ ]]; then
        if grep -l -i -E "(agent|dns|lookup|route|prompt|instruction|tool|function)" "$file" 2>/dev/null; then
            echo "   🎯 Contains agent-related content"
        fi
    fi
done

echo ""
echo "📋 RECOMMENDED NEXT STEPS:"
echo "=========================="
echo "1. 📖 Examine extracted files for:"
echo "   • Agent configuration (agent.json, config.json)"
echo "   • Python source code (*.py files)"
echo "   • Documentation (README.md, *.txt)"
echo "   • Prompt templates or instructions"
echo ""
echo "2. 🔍 Look for:"
echo "   • Function/tool definitions"
echo "   • Input parameter specifications"
echo "   • Expected prompt format"
echo "   • Available commands or operations"
echo ""
echo "3. 🧪 Use findings to create proper test prompts"
echo ""

# Create a summary script
cat > analyze_extracted_code.sh << 'EOF'
#!/bin/bash
echo "🔍 Analyzing Extracted Agent Code"
echo "================================="

echo "📄 Python files found:"
find . -name "*.py" -exec echo "   {}" \;

echo ""
echo "📄 Configuration files found:"
find . -name "*.json" -exec echo "   {}" \;
find . -name "*.yaml" -exec echo "   {}" \;
find . -name "*.yml" -exec echo "   {}" \;

echo ""
echo "📄 Documentation files found:"
find . -name "*.md" -exec echo "   {}" \;
find . -name "*.txt" -exec echo "   {}" \;

echo ""
echo "🔍 Searching for agent-related keywords..."
grep -r -i -n "agent\|dns\|lookup\|route\|prompt\|instruction\|tool\|function" . --include="*.py" --include="*.json" --include="*.yaml" --include="*.yml" --include="*.md" --include="*.txt" 2>/dev/null | head -20

EOF

chmod +x analyze_extracted_code.sh

echo "📝 Created analysis script: analyze_extracted_code.sh"
echo "💡 Run './analyze_extracted_code.sh' to analyze the extracted code"

echo ""
echo "✅ Agent source code extraction completed!"
echo "📁 Check the '$EXTRACT_DIR' directory for extracted files"