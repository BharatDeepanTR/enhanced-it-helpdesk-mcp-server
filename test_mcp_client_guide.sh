#!/bin/bash
# Quick MCP Gateway Test using Curl
# Test AI Calculator through MCP gateway endpoint

set -e

echo "🧪 Testing AI Calculator via MCP Gateway with Curl"
echo "================================================="
echo ""

# Configuration
GATEWAY_NAME="a208194-askjulius-agentcore-gateway-mcp-iam"
TARGET_NAME="target-lambda-direct-ai-bedrock-calculator-mcp"
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "📋 MCP Gateway Test Configuration:"
echo "   Gateway: $GATEWAY_NAME"
echo "   Target: $TARGET_NAME"
echo "   Region: $REGION"
echo "   Account: $ACCOUNT_ID"
echo ""

# Get AWS credentials for API requests
AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
AWS_SESSION_TOKEN=$(aws configure get aws_session_token)

echo "🔍 Step 1: Get MCP Gateway Endpoint..."
echo "====================================="

# Note: You'll need to get the actual gateway endpoint from the console
# For now, let's show the format and provide instructions

echo "⚠️  Gateway Endpoint Required:"
echo ""
echo "1. Go to AWS Console → Bedrock → Agent Core → Gateways"
echo "2. Find gateway: $GATEWAY_NAME"
echo "3. Copy the Gateway Endpoint URL"
echo "4. It should look like:"
echo "   https://gateway-xxxxx.us-east-1.amazonaws.com"
echo ""

# Create MCP test payload
echo "🧪 Step 2: Creating MCP Test Requests..."
echo "======================================="

# Test 1: AI Calculate - Simple math
cat > mcp_test_calculate.json << 'EOF'
{
  "jsonrpc": "2.0",
  "id": "test-1",
  "method": "tools/call",
  "params": {
    "name": "ai_calculate",
    "arguments": {
      "query": "What is 15% of $50,000?"
    }
  }
}
EOF

# Test 2: Explain calculation
cat > mcp_test_explain.json << 'EOF'
{
  "jsonrpc": "2.0", 
  "id": "test-2",
  "method": "tools/call",
  "params": {
    "name": "explain_calculation",
    "arguments": {
      "calculation": "compound interest formula"
    }
  }
}
EOF

# Test 3: Word problem
cat > mcp_test_wordproblem.json << 'EOF'
{
  "jsonrpc": "2.0",
  "id": "test-3", 
  "method": "tools/call",
  "params": {
    "name": "solve_word_problem",
    "arguments": {
      "problem": "A train travels 250 miles in 4 hours. What is its average speed?"
    }
  }
}
EOF

echo "✅ Created MCP test payloads:"
echo "   • mcp_test_calculate.json - Percentage calculation"
echo "   • mcp_test_explain.json - Mathematical explanation"
echo "   • mcp_test_wordproblem.json - Word problem solving"
echo ""

echo "🔧 Step 3: Manual Testing Instructions..."
echo "========================================"

echo ""
echo "📝 Once you have the Gateway Endpoint URL, test with:"
echo ""
echo "# Test 1: AI Calculate"
echo "curl -X POST \"https://YOUR-GATEWAY-ENDPOINT/targets/$TARGET_NAME/invoke\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -H \"Authorization: AWS4-HMAC-SHA256 Credential=...\" \\"
echo "  -d @mcp_test_calculate.json"
echo ""
echo "# Test 2: Explain Calculation"  
echo "curl -X POST \"https://YOUR-GATEWAY-ENDPOINT/targets/$TARGET_NAME/invoke\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -H \"Authorization: AWS4-HMAC-SHA256 Credential=...\" \\"
echo "  -d @mcp_test_explain.json"
echo ""
echo "# Test 3: Word Problem"
echo "curl -X POST \"https://YOUR-GATEWAY-ENDPOINT/targets/$TARGET_NAME/invoke\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -H \"Authorization: AWS4-HMAC-SHA256 Credential=...\" \\"
echo "  -d @mcp_test_wordproblem.json"
echo ""

echo "🎯 Better MCP Client Options:"
echo "============================"
echo ""
echo "1. 🖥️  **Claude Desktop** (Recommended for natural testing)"
echo "   - Download from: https://claude.ai/desktop"
echo "   - Configure MCP gateway connection"
echo "   - Ask: 'What is 15% of \$50,000?' naturally"
echo ""
echo "2. 🔧 **MCP Inspector** (Official testing tool)"
echo "   - Install: npm install -g @modelcontextprotocol/inspector"
echo "   - Run: mcp-inspector"
echo "   - Connect to your gateway endpoint"
echo ""
echo "3. 💻 **VS Code + Claude Dev**"
echo "   - Install Claude Dev extension"
echo "   - Configure MCP gateway in settings"
echo "   - Use AI calculator in your coding workflow"
echo ""
echo "4. 🌐 **Enterprise MCP Client**"
echo "   - If you have an enterprise MCP client already"
echo "   - Configure connection to:"
echo "     Gateway: $GATEWAY_NAME"
echo "     Target: $TARGET_NAME"
echo ""

echo "✅ Next Steps:"
echo "============="
echo "1. Get gateway endpoint URL from AWS console"
echo "2. Choose your preferred MCP client"
echo "3. Test with natural language math queries"
echo "4. Verify Claude-powered responses without permission errors"
echo ""
echo "🎉 Your AI Calculator is ready for MCP client testing!"

# Clean up
echo ""
echo "🧹 Test files created for manual use:"
echo "   • mcp_test_calculate.json"
echo "   • mcp_test_explain.json" 
echo "   • mcp_test_wordproblem.json"
echo ""
echo "🏁 MCP Client Testing Guide Complete!"