#!/bin/bash
# Test script for Application Details MCP Client
# Tests interaction with a208194-chatops_application_details_intent via Agent Core Gateway

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_SCRIPT="$SCRIPT_DIR/mcp_client_application_details.py"
REGION="us-east-1"
GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam"

echo "🧪 Application Details MCP Client Test Suite"
echo "=" * 60
echo "Gateway ID: $GATEWAY_ID"
echo "Region: $REGION"
echo "Target Lambda: a208194-chatops_application_details_intent"
echo ""

# Test cases with various asset IDs
TEST_CASES=(
    "a12345"
    "12345"
    "a208194"
    "208194"
    "a100001"
    "999999"
)

echo "📋 Test Cases:"
for i in "${!TEST_CASES[@]}"; do
    echo "  $((i+1)). ${TEST_CASES[i]}"
done
echo ""

# Function to run test case
run_test_case() {
    local asset_id="$1"
    local test_num="$2"
    
    echo "🔍 Test $test_num: Asset ID '$asset_id'"
    echo "-" * 40
    
    # Create test payload file for CloudShell alternative
    cat > "test_payload_${test_num}.json" << EOF
{
    "gatewayId": "$GATEWAY_ID",
    "agentAliasId": "TSTALIASID",
    "sessionId": "test-session-$(date +%s)",
    "inputText": "Get application details for asset $asset_id",
    "endSession": false
}
EOF
    
    # Method 1: Try Python client directly
    echo "   Method 1: Python MCP Client"
    if python3 "$CLIENT_SCRIPT" "$asset_id" 2>/dev/null; then
        echo "   ✅ Python client succeeded"
        TEST_SUCCESS=true
    else
        echo "   ❌ Python client failed"
        TEST_SUCCESS=false
    fi
    
    # Method 2: AWS CLI direct invocation (if Python fails)
    if [ "$TEST_SUCCESS" != "true" ]; then
        echo "   Method 2: AWS CLI Direct"
        if aws bedrock-agent-runtime invoke-agent-core-gateway \
            --cli-input-json file://test_payload_${test_num}.json \
            --region "$REGION" \
            --output text \
            --query 'completion' 2>/dev/null; then
            echo "   ✅ AWS CLI succeeded"
            TEST_SUCCESS=true
        else
            echo "   ❌ AWS CLI failed"
        fi
    fi
    
    # Method 3: CloudShell script generation
    if [ "$TEST_SUCCESS" != "true" ]; then
        echo "   Method 3: CloudShell Script"
        
        cat > "cloudshell_test_${test_num}.sh" << 'CLOUDSHELL_EOF'
#!/bin/bash
# CloudShell test for Application Details
set -e

ASSET_ID="$1"
GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam"
REGION="us-east-1"

echo "🔍 Testing Application Details for Asset: $ASSET_ID"

# Create payload
cat > payload.json << EOF
{
    "gatewayId": "$GATEWAY_ID",
    "agentAliasId": "TSTALIASID",
    "sessionId": "cloudshell-session-$(date +%s)",
    "inputText": "Get application details for asset $ASSET_ID",
    "endSession": false
}
EOF

echo "📤 Payload:"
cat payload.json

echo ""
echo "🚀 Invoking Agent Core Gateway..."

aws bedrock-agent-runtime invoke-agent-core-gateway \
    --cli-input-json file://payload.json \
    --region "$REGION" \
    --output table

rm -f payload.json
CLOUDSHELL_EOF
        
        chmod +x "cloudshell_test_${test_num}.sh"
        echo "   📝 CloudShell script created: cloudshell_test_${test_num}.sh"
        echo "   💡 Run in CloudShell: ./cloudshell_test_${test_num}.sh $asset_id"
    fi
    
    echo ""
    
    # Clean up test payload
    rm -f "test_payload_${test_num}.json"
}

# Function for connectivity test
test_connectivity() {
    echo "🔗 Testing Gateway Connectivity"
    echo "-" * 40
    
    # Create connectivity test payload
    cat > connectivity_test.json << EOF
{
    "gatewayId": "$GATEWAY_ID",
    "agentAliasId": "TSTALIASID", 
    "sessionId": "connectivity-test-$(date +%s)",
    "inputText": "List available tools",
    "endSession": false
}
EOF
    
    echo "   Method 1: Python connectivity test"
    if python3 -c "
from mcp_client_application_details import ApplicationDetailsMCPClient
client = ApplicationDetailsMCPClient()
success = client.test_connectivity()
print('✅ Connectivity OK' if success else '❌ Connectivity Failed')
" 2>/dev/null; then
        echo "   ✅ Python connectivity test passed"
        CONNECTIVITY_OK=true
    else
        echo "   ❌ Python connectivity test failed"
        CONNECTIVITY_OK=false
    fi
    
    if [ "$CONNECTIVITY_OK" != "true" ]; then
        echo "   Method 2: AWS CLI connectivity test"
        if aws bedrock-agent-runtime invoke-agent-core-gateway \
            --cli-input-json file://connectivity_test.json \
            --region "$REGION" \
            --output text \
            --query 'completion' 2>/dev/null; then
            echo "   ✅ AWS CLI connectivity test passed"
        else
            echo "   ❌ AWS CLI connectivity test failed"
            echo "   💡 Check AWS credentials and gateway status"
        fi
    fi
    
    rm -f connectivity_test.json
    echo ""
}

# Function for comprehensive testing
run_comprehensive_test() {
    echo "🧪 Comprehensive Application Details Test"
    echo "=" * 60
    
    # Test connectivity first
    test_connectivity
    
    # Run all test cases
    for i in "${!TEST_CASES[@]}"; do
        run_test_case "${TEST_CASES[i]}" "$((i+1))"
    done
    
    echo "📊 Test Summary"
    echo "-" * 40
    echo "   Total test cases: ${#TEST_CASES[@]}"
    echo "   Gateway: $GATEWAY_ID"
    echo "   Region: $REGION"
    echo "   Lambda: a208194-chatops_application_details_intent"
    echo ""
    echo "💡 If tests fail:"
    echo "   1. Check AWS credentials: aws sts get-caller-identity"
    echo "   2. Verify gateway exists and is active"
    echo "   3. Confirm target Lambda is deployed"
    echo "   4. Use CloudShell scripts as alternative"
}

# Function for interactive testing
interactive_test() {
    echo "🎮 Interactive Testing Mode"
    echo "-" * 40
    echo "Commands:"
    echo "  test <asset_id> - Test specific asset ID"
    echo "  connectivity    - Test gateway connectivity"
    echo "  python         - Start Python interactive client"
    echo "  quit           - Exit"
    echo ""
    
    while true; do
        read -p "🔍 Enter command: " command args
        
        case "$command" in
            "test")
                if [ -n "$args" ]; then
                    run_test_case "$args" "interactive"
                else
                    echo "⚠️ Usage: test <asset_id>"
                fi
                ;;
            "connectivity")
                test_connectivity
                ;;
            "python")
                echo "🐍 Starting Python interactive client..."
                python3 "$CLIENT_SCRIPT"
                ;;
            "quit"|"exit"|"q")
                echo "👋 Goodbye!"
                break
                ;;
            *)
                echo "⚠️ Unknown command. Try: test, connectivity, python, or quit"
                ;;
        esac
        echo ""
    done
}

# Main execution logic
case "${1:-}" in
    "comprehensive"|"all")
        run_comprehensive_test
        ;;
    "connectivity"|"connect")
        test_connectivity
        ;;
    "interactive"|"i")
        interactive_test
        ;;
    "test")
        if [ -n "$2" ]; then
            run_test_case "$2" "single"
        else
            echo "Usage: $0 test <asset_id>"
            exit 1
        fi
        ;;
    *)
        echo "🚀 Application Details MCP Client Test Suite"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  comprehensive  - Run all test cases"
        echo "  connectivity   - Test gateway connectivity"
        echo "  interactive    - Interactive testing mode"
        echo "  test <asset_id> - Test specific asset ID"
        echo ""
        echo "Examples:"
        echo "  $0 comprehensive"
        echo "  $0 connectivity"
        echo "  $0 test a12345"
        echo "  $0 interactive"
        ;;
esac