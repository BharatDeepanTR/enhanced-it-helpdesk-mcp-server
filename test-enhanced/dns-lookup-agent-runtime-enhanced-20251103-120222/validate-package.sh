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
