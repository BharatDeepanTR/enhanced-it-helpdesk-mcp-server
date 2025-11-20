#!/bin/bash
# CloudShell Application Details Gateway Test
# Comprehensive testing for a208194-chatops_application_details_intent via Agent Core Gateway

set -e

# Configuration
GATEWAY_ID="a208194-askjulius-agentcore-mcp-gateway"
GATEWAY_URL="https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
TARGET_LAMBDA="a208194-chatops_application_details_intent"
REGION="us-east-1"
AGENT_ALIAS_ID="TSTALIASID"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 CloudShell Application Details Gateway Test${NC}"
echo "=" * 60
echo "Gateway ID: $GATEWAY_ID"
echo "Target Lambda: $TARGET_LAMBDA"
echo "Region: $REGION"
echo "Agent Alias: $AGENT_ALIAS_ID"
echo ""

# Function to test AWS connectivity
test_aws_connectivity() {
    echo -e "${BLUE}🔍 Testing AWS connectivity...${NC}"
    
    if aws sts get-caller-identity > /dev/null 2>&1; then
        echo -e "${GREEN}✅ AWS credentials working${NC}"
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
        echo "   Account ID: $ACCOUNT_ID"
        echo "   User/Role: $USER_ARN"
        return 0
    else
        echo -e "${RED}❌ AWS credentials not working${NC}"
        return 1
    fi
}

# Function to verify target Lambda exists
verify_lambda() {
    echo -e "${BLUE}🔍 Verifying target Lambda function...${NC}"
    
    if aws lambda get-function --function-name "$TARGET_LAMBDA" --region "$REGION" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Lambda function exists and accessible${NC}"
        
        # Get Lambda details
        LAMBDA_RUNTIME=$(aws lambda get-function --function-name "$TARGET_LAMBDA" --region "$REGION" --query 'Configuration.Runtime' --output text)
        LAMBDA_UPDATED=$(aws lambda get-function --function-name "$TARGET_LAMBDA" --region "$REGION" --query 'Configuration.LastModified' --output text)
        
        echo "   Runtime: $LAMBDA_RUNTIME"
        echo "   Last Modified: $LAMBDA_UPDATED"
        return 0
    else
        echo -e "${RED}❌ Cannot access Lambda function${NC}"
        return 1
    fi
}

# Function to check if gateway exists
check_gateway() {
    echo -e "${BLUE}🔍 Checking gateway status...${NC}"
    
    # Try different commands to check gateway
    if aws bedrock-agent-runtime list-agent-core-gateways --region "$REGION" > /dev/null 2>&1; then
        if aws bedrock-agent-runtime list-agent-core-gateways --region "$REGION" --query "gateways[?gatewayId=='$GATEWAY_ID']" --output text | grep -q "$GATEWAY_ID"; then
            echo -e "${GREEN}✅ Gateway found and accessible${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️ Gateway command works but gateway not found in list${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️ Cannot list gateways (may not be available in CLI)${NC}"
        return 1
    fi
}

# Function to test direct Lambda invocation
test_direct_lambda() {
    local asset_id="$1"
    echo -e "${BLUE}🧪 Testing direct Lambda invocation for asset: $asset_id${NC}"
    
    # Create test payload for direct Lambda call
    cat > direct_lambda_payload.json << EOF
{
    "asset_id": "$asset_id"
}
EOF
    
    echo "   📤 Payload: {\"asset_id\": \"$asset_id\"}"
    
    if aws lambda invoke \
        --function-name "$TARGET_LAMBDA" \
        --region "$REGION" \
        --payload file://direct_lambda_payload.json \
        direct_lambda_response.json > /dev/null 2>&1; then
        
        echo -e "${GREEN}   ✅ Direct Lambda invocation successful${NC}"
        echo "   📥 Response:"
        cat direct_lambda_response.json | jq . 2>/dev/null || cat direct_lambda_response.json
        echo ""
        
        # Clean up
        rm -f direct_lambda_payload.json direct_lambda_response.json
        return 0
    else
        echo -e "${RED}   ❌ Direct Lambda invocation failed${NC}"
        rm -f direct_lambda_payload.json direct_lambda_response.json
        return 1
    fi
}

# Function to test HTTP MCP endpoint
test_http_mcp() {
    local asset_id="$1"
    local test_number="$2"
    
    echo -e "${BLUE}🌐 Test $test_number: HTTP MCP endpoint for asset: $asset_id${NC}"
    
    # Create HTTP test script
    cat > http_test_$test_number.py << 'HTTP_EOF'
import json
import uuid
import requests
import boto3
from requests_aws4auth import AWS4Auth
import sys

def test_http_mcp(gateway_url, asset_id, region="us-east-1"):
    try:
        # Get AWS credentials
        session = boto3.Session()
        credentials = session.get_credentials()
        
        if not credentials:
            print("❌ AWS credentials not found")
            return False
        
        # Set up AWS SigV4 authentication
        auth = AWS4Auth(
            credentials.access_key,
            credentials.secret_key,
            region,
            'bedrock-agentcore',
            session_token=credentials.token
        )
        
        # Clean asset ID
        clean_asset_id = asset_id.strip()
        if not clean_asset_id.startswith('a') and clean_asset_id.isdigit():
            clean_asset_id = f"a{clean_asset_id}"
        
        # Test tools/call
        payload = {
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": {
                "name": "get_application_details",
                "arguments": {
                    "asset_id": clean_asset_id
                }
            },
            "id": str(uuid.uuid4())
        }
        
        headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
        
        print(f"   🔧 Testing HTTP MCP call for asset: {clean_asset_id}")
        
        response = requests.post(
            gateway_url,
            json=payload,
            headers=headers,
            auth=auth,
            timeout=30
        )
        
        print(f"   📥 HTTP Status: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print(f"   ✅ HTTP MCP call successful")
            
            if "result" in result:
                response_result = result["result"]
                if isinstance(response_result, dict) and "content" in response_result:
                    content = response_result["content"]
                    if isinstance(content, list) and len(content) > 0:
                        text_content = content[0].get("text", "No text content")
                        print(f"   💬 Application Details: {text_content}")
                
            print(f"   📊 Full Response: {json.dumps(result, indent=2)}")
            return True
        else:
            print(f"   ❌ HTTP request failed: {response.text}")
            return False
            
    except Exception as e:
        print(f"   ❌ HTTP test exception: {e}")
        return False

if __name__ == "__main__":
    gateway_url = sys.argv[1]
    asset_id = sys.argv[2]
    result = test_http_mcp(gateway_url, asset_id)
    sys.exit(0 if result else 1)
HTTP_EOF
    
    # Run HTTP test
    if python3 http_test_$test_number.py "$GATEWAY_URL" "$asset_id" 2>/dev/null; then
        echo -e "${GREEN}   ✅ HTTP MCP test successful${NC}"
        rm -f http_test_$test_number.py
        return 0
    else
        echo -e "${RED}   ❌ HTTP MCP test failed${NC}"
        rm -f http_test_$test_number.py
        return 1
    fi
}
test_gateway_invocation() {
    local asset_id="$1"
    local test_number="$2"
    
    echo -e "${BLUE}🧪 Test $test_number: Gateway invocation for asset: $asset_id${NC}"
    
    # Generate unique session ID
    SESSION_ID="app-details-test-$(date +%s)-$test_number"
    
    # Create gateway payload
    cat > gateway_payload_$test_number.json << EOF
{
    "gatewayId": "$GATEWAY_ID",
    "agentAliasId": "$AGENT_ALIAS_ID",
    "sessionId": "$SESSION_ID",
    "inputText": "Get application details for asset $asset_id",
    "endSession": false
}
EOF
    
    echo "   📤 Request:"
    echo "      Gateway ID: $GATEWAY_ID"
    echo "      Session ID: $SESSION_ID"
    echo "      Input: Get application details for asset $asset_id"
    
    # Try gateway invocation
    if aws bedrock-agent-runtime invoke-agent-core-gateway \
        --cli-input-json file://gateway_payload_$test_number.json \
        --region "$REGION" \
        --output json > gateway_response_$test_number.json 2>&1; then
        
        echo -e "${GREEN}   ✅ Gateway invocation successful${NC}"
        echo "   📥 Response:"
        
        # Parse and display response
        if command -v jq > /dev/null 2>&1; then
            cat gateway_response_$test_number.json | jq .
        else
            cat gateway_response_$test_number.json
        fi
        echo ""
        
        # Extract completion if available
        if command -v jq > /dev/null 2>&1; then
            COMPLETION=$(cat gateway_response_$test_number.json | jq -r '.completion // empty' 2>/dev/null)
            if [ ! -z "$COMPLETION" ]; then
                echo "   💬 Completion: $COMPLETION"
            fi
        fi
        
        return 0
    else
        echo -e "${RED}   ❌ Gateway invocation failed${NC}"
        echo "   📥 Error response:"
        cat gateway_response_$test_number.json
        echo ""
        return 1
    fi
}

# Function to run comprehensive test
run_comprehensive_test() {
    echo -e "${BLUE}🧪 Running Comprehensive Test Suite${NC}"
    echo "=" * 50
    
    # Test cases
    TEST_CASES=("a12345" "12345" "a208194" "208194" "a100001")
    
    echo "📋 Test cases: ${TEST_CASES[*]}"
    echo ""
    
    # Pre-flight checks
    echo -e "${YELLOW}📋 Pre-flight checks...${NC}"
    
    if ! test_aws_connectivity; then
        echo -e "${RED}❌ AWS connectivity failed - aborting tests${NC}"
        return 1
    fi
    
    if ! verify_lambda; then
        echo -e "${YELLOW}⚠️ Lambda verification failed - continuing anyway${NC}"
    fi
    
    check_gateway # Non-blocking
    
    echo ""
    echo -e "${YELLOW}🚀 Starting test execution...${NC}"
    
    # Test each case
    SUCCESS_COUNT=0
    TOTAL_TESTS=${#TEST_CASES[@]}
    
    for i in "${!TEST_CASES[@]}"; do
        asset_id="${TEST_CASES[i]}"
        test_num=$((i+1))
        
        echo ""
        echo -e "${BLUE}" + "=" * 40 + "${NC}"
        
        if test_gateway_invocation "$asset_id" "$test_num"; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            # If gateway fails, try HTTP MCP
            echo -e "${YELLOW}   🔄 Trying HTTP MCP as fallback...${NC}"
            if test_http_mcp "$asset_id" "$test_num"; then
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            else
                # If HTTP MCP fails, try direct Lambda
                echo -e "${YELLOW}   🔄 Trying direct Lambda as final fallback...${NC}"
                test_direct_lambda "$asset_id"
            fi
        fi
        
        # Clean up test files
        rm -f gateway_payload_$test_num.json gateway_response_$test_num.json
    done
    
    echo ""
    echo -e "${BLUE}📊 Test Summary${NC}"
    echo "=" * 30
    echo "Total tests: $TOTAL_TESTS"
    echo "Successful: $SUCCESS_COUNT"
    echo "Failed: $((TOTAL_TESTS - SUCCESS_COUNT))"
    
    if [ $SUCCESS_COUNT -eq $TOTAL_TESTS ]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
    elif [ $SUCCESS_COUNT -gt 0 ]; then
        echo -e "${YELLOW}⚠️ Partial success${NC}"
    else
        echo -e "${RED}❌ All tests failed${NC}"
    fi
}

# Function for single test
run_single_test() {
    local asset_id="$1"
    
    echo -e "${BLUE}🧪 Single Test for Asset: $asset_id${NC}"
    echo "=" * 40
    
    # Pre-flight check
    if ! test_aws_connectivity; then
        echo -e "${RED}❌ AWS connectivity failed${NC}"
        return 1
    fi
    
    # Run test
    if test_gateway_invocation "$asset_id" "single"; then
        echo -e "${GREEN}✅ Test completed successfully${NC}"
    else
        echo -e "${YELLOW}🔄 Trying direct Lambda fallback...${NC}"
        test_direct_lambda "$asset_id"
    fi
    
    # Clean up
    rm -f gateway_payload_single.json gateway_response_single.json
}

# Function to display help
show_help() {
    echo "🚀 CloudShell Application Details Gateway Test"
    echo ""
    echo "Usage: $0 [command] [asset_id]"
    echo ""
    echo "Commands:"
    echo "  test <asset_id>    - Test specific asset ID"
    echo "  comprehensive      - Run all test cases"
    echo "  check              - Run connectivity checks only"
    echo "  lambda <asset_id>  - Test direct Lambda only"
    echo "  help               - Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 test a12345"
    echo "  $0 comprehensive"
    echo "  $0 check"
    echo "  $0 lambda a208194"
}

# Main execution logic
case "${1:-comprehensive}" in
    "test")
        if [ -n "$2" ]; then
            run_single_test "$2"
        else
            echo -e "${RED}❌ Asset ID required for single test${NC}"
            echo "Usage: $0 test <asset_id>"
            exit 1
        fi
        ;;
    "comprehensive"|"all")
        run_comprehensive_test
        ;;
    "check"|"verify")
        test_aws_connectivity
        verify_lambda
        check_gateway
        ;;
    "lambda"|"direct")
        if [ -n "$2" ]; then
            if test_aws_connectivity; then
                test_direct_lambda "$2"
            fi
        else
            echo -e "${RED}❌ Asset ID required for direct Lambda test${NC}"
            echo "Usage: $0 lambda <asset_id>"
            exit 1
        fi
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo -e "${YELLOW}⚠️ Unknown command: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}🏁 Test execution completed${NC}"