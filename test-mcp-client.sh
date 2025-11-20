#!/bin/bash
# MCP Client Test Runner for Agent Core Gateway Calculator
# Multiple options for testing your calculator target

set -e

echo "🧮 MCP Client for Agent Core Gateway Calculator"
echo "=============================================="
echo ""

# Configuration
GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam"
REGION="us-east-1"
TARGET_NAME="target-direct-calculator-lambda"

echo "📋 Configuration:"
echo "   Gateway ID: $GATEWAY_ID"
echo "   Region: $REGION"
echo "   Target: $TARGET_NAME"
echo ""

# Check Python availability
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
else
    PYTHON_CMD=""
fi

# Check Node.js availability
if command -v node &> /dev/null; then
    NODE_AVAILABLE=true
else
    NODE_AVAILABLE=false
fi

# Function to show usage
show_usage() {
    echo "🎯 Usage Options:"
    echo ""
    echo "Quick Tests:"
    echo "   $0 quick              # Quick single test"
    echo "   $0 python-quick       # Python quick test"
    echo "   $0 node-quick         # Node.js quick test (if available)"
    echo ""
    echo "Full Test Suites:"
    echo "   $0 test               # Python full test suite"
    echo "   $0 python-test        # Python comprehensive tests"
    echo "   $0 node-test          # Node.js test suite (if available)"
    echo ""
    echo "Interactive Modes:"
    echo "   $0 interactive        # Python interactive calculator"
    echo "   $0 python-interactive # Python interactive mode"
    echo "   $0 node-interactive   # Node.js interactive mode (if available)"
    echo ""
    echo "Manual Tests:"
    echo "   $0 manual             # Show manual testing steps"
    echo "   $0 console            # AWS Console testing guide"
}

# Parse command line arguments
MODE=${1:-help}

case $MODE in
    "quick"|"python-quick")
        if [ -n "$PYTHON_CMD" ]; then
            echo "🚀 Running Python Quick Test..."
            $PYTHON_CMD simple_mcp_client.py quick
        else
            echo "❌ Python not available. Please install Python 3."
            exit 1
        fi
        ;;
    
    "node-quick")
        if [ "$NODE_AVAILABLE" = true ]; then
            echo "🚀 Running Node.js Quick Test..."
            node mcp_client.js quick
        else
            echo "❌ Node.js not available. Please install Node.js."
            exit 1
        fi
        ;;
    
    "test"|"python-test")
        if [ -n "$PYTHON_CMD" ]; then
            echo "🧪 Running Python Comprehensive Test Suite..."
            $PYTHON_CMD mcp_client_calculator.py test
        else
            echo "❌ Python not available. Please install Python 3."
            exit 1
        fi
        ;;
    
    "node-test")
        if [ "$NODE_AVAILABLE" = true ]; then
            echo "🧪 Running Node.js Test Suite..."
            node mcp_client.js test
        else
            echo "❌ Node.js not available. Please install Node.js."
            exit 1
        fi
        ;;
    
    "interactive"|"python-interactive")
        if [ -n "$PYTHON_CMD" ]; then
            echo "🎮 Starting Python Interactive Calculator..."
            $PYTHON_CMD simple_mcp_client.py interactive
        else
            echo "❌ Python not available. Please install Python 3."
            exit 1
        fi
        ;;
    
    "node-interactive")
        if [ "$NODE_AVAILABLE" = true ]; then
            echo "🎮 Starting Node.js Interactive Calculator..."
            node mcp_client.js interactive
        else
            echo "❌ Node.js not available. Please install Node.js."
            exit 1
        fi
        ;;
    
    "manual")
        echo "📖 Manual Testing Steps:"
        echo "======================="
        echo ""
        echo "1. 🌐 AWS Console Lambda Test:"
        echo "   • Go to AWS Console → Lambda → a208194-calculator-mcp-server"
        echo "   • Click 'Test' tab"
        echo "   • Create test event: {\"jsonrpc\":\"2.0\",\"method\":\"tools/list\",\"id\":1}"
        echo "   • Should return list of 10 calculator tools"
        echo ""
        echo "2. 🎯 Gateway Status Check:"
        echo "   • Go to AWS Console → Bedrock → Agent Core → Gateways"
        echo "   • Select: $GATEWAY_ID"
        echo "   • Check Targets tab → $TARGET_NAME should be 'Active'"
        echo ""
        echo "3. 🌩️ CloudShell Alternative:"
        echo "   • Open AWS CloudShell from console"
        echo "   • Upload and run test scripts there"
        echo "   • No encoding issues in CloudShell environment"
        ;;
    
    "console")
        echo "🖥️ AWS Console Testing Guide:"
        echo "============================="
        echo ""
        echo "📍 Direct URLs (replace ACCOUNT_ID):"
        echo ""
        echo "Lambda Function:"
        echo "https://console.aws.amazon.com/lambda/home?region=$REGION#/functions/a208194-calculator-mcp-server"
        echo ""
        echo "Agent Core Gateway:"
        echo "https://console.aws.amazon.com/bedrock/home?region=$REGION#/agent-core/gateways/$GATEWAY_ID"
        echo ""
        echo "CloudWatch Logs:"
        echo "https://console.aws.amazon.com/cloudwatch/home?region=$REGION#logsV2:log-groups/log-group/\$252Faws\$252Flambda\$252Fa208194-calculator-mcp-server"
        echo ""
        echo "🔧 Quick Validation Steps:"
        echo "1. Check Lambda function is Active"
        echo "2. Verify Gateway target status is Active"
        echo "3. Test Lambda directly with MCP payload"
        echo "4. Monitor CloudWatch logs for execution"
        ;;
    
    "install")
        echo "📦 Installing Dependencies..."
        echo ""
        if [ -n "$PYTHON_CMD" ]; then
            echo "Installing Python dependencies..."
            pip install boto3 2>/dev/null || pip3 install boto3 2>/dev/null || echo "Please install boto3: pip install boto3"
        fi
        
        if [ "$NODE_AVAILABLE" = true ]; then
            echo "Installing Node.js dependencies..."
            npm install @aws-sdk/client-bedrock-agent-runtime readline-sync 2>/dev/null || echo "Please install npm dependencies"
        fi
        echo "✅ Installation complete"
        ;;
    
    "help"|*)
        show_usage
        ;;
esac

echo ""
echo "🔧 Environment Status:"
echo "   Python: $(if [ -n "$PYTHON_CMD" ]; then echo "✅ Available ($PYTHON_CMD)"; else echo "❌ Not found"; fi)"
echo "   Node.js: $(if [ "$NODE_AVAILABLE" = true ]; then echo "✅ Available"; else echo "❌ Not found"; fi)"
echo "   AWS CLI: $(if command -v aws &> /dev/null; then echo "✅ Available"; else echo "❌ Not found"; fi)"
echo ""
echo "💡 Recommended: Start with './test-mcp-client.sh quick' for fastest validation!"