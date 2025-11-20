#!/bin/bash
# Script to discover Bedrock Agent Core endpoint and action details

echo "🔍 Discovering Bedrock Agent Information..."
echo ""

# Check AWS configuration
echo "📋 AWS Configuration:"
aws sts get-caller-identity --query '[Account,Arn]' --output table 2>/dev/null || echo "❌ AWS CLI not configured"
echo ""

# List available agents
echo "🤖 Available Bedrock Agents:"
aws bedrock-agent list-agents --region us-east-1 --query 'agentSummaries[*].[agentName,agentId,agentStatus]' --output table 2>/dev/null || echo "❌ No agents found or permission denied"
echo ""

# Instructions for manual lookup
echo "📝 Manual Steps to Find Your Agent Endpoint:"
echo ""
echo "1. AWS Console Method:"
echo "   → Go to Amazon Bedrock Console"
echo "   → Navigate to 'Agents' section"
echo "   → Select your agent"
echo "   → Look for 'Agent Endpoint' or 'Invoke URL'"
echo ""
echo "2. Agent Core Runtime Endpoint Format:"
echo "   https://bedrock-agent-runtime.{region}.amazonaws.com/agents/{agent-id}/agentAliases/{alias-id}/sessions/{session-id}/text"
echo ""
echo "3. Direct Container Endpoint (if exposed):"
echo "   http://{your-container-host}:8080/lookup?domain={domain}"
echo ""

# Test basic DNS functionality
echo "🧪 Testing Local DNS Lookup Functionality:"
if command -v python3 &> /dev/null; then
    python3 -c "
import socket
try:
    result = socket.gethostbyname('aws.amazon.com')
    print(f'✅ DNS Resolution Test: aws.amazon.com → {result}')
except Exception as e:
    print(f'❌ DNS Resolution Test Failed: {e}')
"
else
    echo "❌ Python3 not available for testing"
fi
echo ""

echo "🎯 Next Steps:"
echo "1. Find your agent ID from AWS Console or CLI output above"
echo "2. Test direct container endpoint first: curl http://{endpoint}:8080/health"
echo "3. Then test DNS lookup: curl 'http://{endpoint}:8080/lookup?domain=aws.amazon.com'"
echo "4. Finally test through Bedrock Agent API if needed"