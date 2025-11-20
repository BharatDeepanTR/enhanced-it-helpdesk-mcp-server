#!/bin/bash
# Check for Available Bedrock Agent Core Gateway CLI Commands
# Updated for latest AWS CLI capabilities

echo "🔍 Checking AWS CLI Support for Bedrock Agent Core Gateway"
echo "=========================================================="
echo ""

# Check AWS CLI version
echo "📋 AWS CLI Version:"
aws --version 2>/dev/null || echo "AWS CLI not installed"
echo ""

# Check available Bedrock services
echo "🔧 Available Bedrock Services:"
echo "------------------------------"

# Method 1: Check bedrock service
echo "1. Checking 'aws bedrock' commands..."
if aws bedrock help 2>/dev/null | grep -i "agent\|gateway" | head -10; then
    echo "   ✅ Found agent-related commands in bedrock service"
else
    echo "   ❌ No agent/gateway commands found in bedrock service"
fi
echo ""

# Method 2: Check bedrock-agent service
echo "2. Checking 'aws bedrock-agent' commands..."
if command -v aws >/dev/null 2>&1; then
    if aws bedrock-agent help 2>/dev/null | head -5; then
        echo "   ✅ bedrock-agent service available"
        echo ""
        echo "   Available bedrock-agent commands:"
        aws bedrock-agent help 2>/dev/null | grep -E "^   [a-z-]+" | head -20
    else
        echo "   ❌ bedrock-agent service not available"
    fi
else
    echo "   ❌ AWS CLI not available"
fi
echo ""

# Method 3: Check bedrock-agent-runtime service
echo "3. Checking 'aws bedrock-agent-runtime' commands..."
if aws bedrock-agent-runtime help 2>/dev/null | head -5; then
    echo "   ✅ bedrock-agent-runtime service available"
    echo ""
    echo "   Available bedrock-agent-runtime commands:"
    aws bedrock-agent-runtime help 2>/dev/null | grep -E "^   [a-z-]+" | head -10
else
    echo "   ❌ bedrock-agent-runtime service not available"
fi
echo ""

# Method 4: Try specific gateway commands
echo "4. Testing specific Agent Core Gateway commands..."
echo "   Testing: aws bedrock-agent create-agent-core-gateway..."
if aws bedrock-agent create-agent-core-gateway help 2>/dev/null; then
    echo "   ✅ create-agent-core-gateway command found!"
else
    echo "   ❌ create-agent-core-gateway command not found"
fi

echo "   Testing: aws bedrock create-agent-core-gateway..."
if aws bedrock create-agent-core-gateway help 2>/dev/null; then
    echo "   ✅ create-agent-core-gateway command found in bedrock service!"
else
    echo "   ❌ create-agent-core-gateway command not found in bedrock service"
fi

echo "   Testing: aws bedrock-agent-runtime create-gateway..."
if aws bedrock-agent-runtime create-gateway help 2>/dev/null; then
    echo "   ✅ create-gateway command found in bedrock-agent-runtime!"
else
    echo "   ❌ create-gateway command not found in bedrock-agent-runtime"
fi
echo ""

# Method 5: Check for any gateway-related commands
echo "5. Searching for any gateway-related commands..."
echo "   Searching bedrock services for 'gateway' keyword..."

for service in "bedrock" "bedrock-agent" "bedrock-agent-runtime"; do
    echo "   Checking $service service:"
    if aws $service help 2>/dev/null | grep -i gateway; then
        echo "      ✅ Found gateway commands in $service"
    else
        echo "      ❌ No gateway commands in $service"
    fi
done
echo ""

# Method 6: Try alternative command patterns
echo "6. Testing alternative command patterns..."

# Test variations that might exist
POTENTIAL_COMMANDS=(
    "bedrock-agent create-gateway"
    "bedrock-agent create-agent-gateway"
    "bedrock-agent create-core-gateway"
    "bedrock create-gateway"
    "bedrock create-agent-gateway"
    "bedrock-agent-runtime create-gateway"
)

for cmd in "${POTENTIAL_COMMANDS[@]}"; do
    echo "   Testing: aws $cmd..."
    if aws $cmd help 2>/dev/null >/dev/null; then
        echo "      ✅ Command exists: aws $cmd"
        aws $cmd help 2>/dev/null | head -10
    else
        echo "      ❌ Command not found: aws $cmd"
    fi
done
echo ""

echo "📊 Summary of Findings"
echo "====================="
echo ""
echo "Current CLI Support Status:"

# Check if any gateway commands were found
GATEWAY_CLI_FOUND=false

# Test one more time for definitive answer
if aws bedrock-agent help 2>/dev/null | grep -q "create.*gateway"; then
    GATEWAY_CLI_FOUND=true
fi

if [ "$GATEWAY_CLI_FOUND" = "true" ]; then
    echo "   ✅ Bedrock Agent Core Gateway CLI commands are available"
    echo "   🎯 Recommended approach: Use AWS CLI"
else
    echo "   ❌ Bedrock Agent Core Gateway CLI commands not yet available"
    echo "   🎯 Recommended approach: AWS Console or CloudFormation"
fi

echo ""
echo "💡 Alternative Approaches:"
echo "=========================="
echo ""
echo "1. 🌐 AWS Console (Manual)"
echo "   - Most reliable for new services"
echo "   - Use service role ARN directly if dropdown is empty"
echo ""
echo "2. 📜 CloudFormation (if supported)"
echo "   - Infrastructure as Code approach"
echo "   - May have limited support for Agent Core Gateway"
echo ""
echo "3. 🔧 AWS CDK (if supported)"
echo "   - Programmatic approach"
echo "   - Check latest CDK documentation"
echo ""
echo "4. 📡 Direct REST API"
echo "   - Use AWS API directly with curl/boto3"
echo "   - Most advanced option"
echo ""

echo "🎯 Immediate Recommendation for Your Case:"
echo "=========================================="
echo ""
echo "Since you're using CloudShell temporary credentials:"
echo ""
echo "Option A: Enhanced Console Approach"
echo "   1. Fix service role visibility issues first"
echo "   2. Use browser troubleshooting techniques"
echo "   3. Manually enter service role ARN if needed"
echo ""
echo "Option B: Wait for CLI Support"
echo "   Agent Core Gateway is relatively new"
echo "   CLI support may be added in future AWS CLI updates"
echo ""
echo "Option C: Use Existing Gateway"
echo "   If you have existing Agent Core Gateways,"
echo "   check how their service roles are configured"
echo ""

echo "🔍 To check for the latest CLI updates:"
echo "   aws --version"
echo "   pip install --upgrade awscli"
echo "   # or"
echo "   aws --version && curl -s https://awscli.amazonaws.com/CHANGELOG.rst | head -20"