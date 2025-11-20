#!/bin/bash

echo "🔧 Fixed DNS Agent Core Runtime CLI Testing"
echo "=========================================="

# Your runtime ARN (double-check this is correct)
RUNTIME_ARN="arn:aws:bedrock-agentcore:us-east-1:818565325759:runtime/a208194_chatops_route_dns_lookup-Zg3E6G5ZDV"
REGION="us-east-1"

# Function to test with proper base64 encoding
test_dns_query() {
    local test_name="$1"
    local query="$2"
    local output_file="$3"
    
    echo ""
    echo "Test: $test_name"
    echo "Query: $query"
    echo "------------------------"
    
    # Create JSON payload
    payload='{"query": "'$query'"}'
    echo "Payload: $payload"
    
    # Base64 encode the payload properly
    encoded_payload=$(echo -n "$payload" | base64 -w 0)
    echo "Encoded (first 50 chars): ${encoded_payload:0:50}..."
    
    # Make the API call
    aws bedrock-agentcore invoke-agent-runtime \
        --agent-runtime-arn "$RUNTIME_ARN" \
        --payload "$encoded_payload" \
        --region "$REGION" \
        "$output_file" \
        --content-type "application/json" 2>&1
    
    local exit_code=$?
    if [ $exit_code -eq 0 ] && [ -f "$output_file" ]; then
        echo "✅ Success! Response:"
        cat "$output_file"
    else
        echo "❌ Failed with exit code: $exit_code"
        if [ -f "$output_file" ]; then
            echo "Error details:"
            cat "$output_file"
        fi
    fi
    echo "========================"
}

# Test 1: Verify runtime exists first
echo "🔍 Checking if runtime exists..."
aws bedrock-agentcore get-agent-card --agent-runtime-arn "$RUNTIME_ARN" --region "$REGION" 2>&1
echo ""

# Test 2: Simple DNS queries
test_dns_query "Google DNS Lookup" "What is the IP address of google.com?" "/tmp/response1.json"
test_dns_query "Microsoft DNS Lookup" "Look up IP for microsoft.com" "/tmp/response2.json"
test_dns_query "GitHub DNS Lookup" "Find IP address for github.com" "/tmp/response3.json"

echo ""
echo "📋 Summary of response files:"
for i in {1..3}; do
    if [ -f "/tmp/response$i.json" ]; then
        echo "✅ /tmp/response$i.json exists ($(wc -c < /tmp/response$i.json) bytes)"
    else
        echo "❌ /tmp/response$i.json missing"
    fi
done

echo ""
echo "🔍 Troubleshooting Tips:"
echo "1. If you get 404 errors, check the runtime ARN"
echo "2. If base64 issues persist, try manual encoding"
echo "3. Check CloudWatch logs for detailed error info"
echo "4. Verify IAM permissions for bedrock-agentcore:InvokeAgentRuntime"