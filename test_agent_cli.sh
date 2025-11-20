#!/bin/bash

# DNS Agent Core Runtime Testing Script
# Agent Runtime ARN: arn:aws:bedrock-agentcore:us-east-1:818565325759:runtime/a208194_chatops_route_dns_lookup-Zg3E6G5ZDV

AGENT_ARN="arn:aws:bedrock-agentcore:us-east-1:818565325759:runtime/a208194_chatops_route_dns_lookup-Zg3E6G5ZDV"
REGION="us-east-1"

echo "🧪 Testing DNS Agent Core Runtime via CLI"
echo "========================================="

# Test 1: Basic DNS Lookup
echo "Test 1: Google DNS Lookup"
echo '{"query": "What is the IP address of google.com?"}' > /tmp/test1.json
aws bedrock-agentcore invoke-agent-runtime \
  --agent-runtime-arn "$AGENT_ARN" \
  --payload file:///tmp/test1.json \
  --region "$REGION" \
  /tmp/response1.json

echo "Response saved to /tmp/response1.json"
cat /tmp/response1.json
echo -e "\n"

# Test 2: Microsoft DNS Lookup
echo "Test 2: Microsoft DNS Lookup"
echo '{"query": "Look up DNS records for microsoft.com"}' > /tmp/test2.json
aws bedrock-agentcore invoke-agent-runtime \
  --agent-runtime-arn "$AGENT_ARN" \
  --payload file:///tmp/test2.json \
  --region "$REGION" \
  /tmp/response2.json

echo "Response saved to /tmp/response2.json"
cat /tmp/response2.json
echo -e "\n"

# Test 3: GitHub DNS Lookup
echo "Test 3: GitHub DNS Lookup"
echo '{"query": "Find IP address for github.com"}' > /tmp/test3.json
aws bedrock-agentcore invoke-agent-runtime \
  --agent-runtime-arn "$AGENT_ARN" \
  --payload file:///tmp/test3.json \
  --region "$REGION" \
  /tmp/response3.json

echo "Response saved to /tmp/response3.json"
cat /tmp/response3.json
echo -e "\n"

echo "✅ Testing completed! Check response files for results."