# Quick Lambda Code Check Commands

# Check Lambda configuration and code location
aws lambda get-function \
  --function-name a208194-ai-bedrock-calculator-mcp-server \
  --region us-east-1 \
  --query '{FunctionName:Configuration.FunctionName,Runtime:Configuration.Runtime,Handler:Configuration.Handler,CodeSize:Configuration.CodeSize,LastModified:Configuration.LastModified,CodeLocation:Code.Location}'

# Test with simpler payload to see actual behavior
echo '{"test": "ping"}' > simple_test.json
aws lambda invoke \
  --function-name a208194-ai-bedrock-calculator-mcp-server \
  --region us-east-1 \
  --payload file://simple_test.json \
  test_response.json

echo "Response:"
cat test_response.json

# Check if there are any environment variables that might indicate MCP setup
aws lambda get-function-configuration \
  --function-name a208194-ai-bedrock-calculator-mcp-server \
  --region us-east-1 \
  --query 'Environment'