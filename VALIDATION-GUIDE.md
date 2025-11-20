# Manual Validation Steps for Calculator Target

## Method 1: AWS CLI Testing (Recommended)

Run the automated test script:
```bash
./test-calculator-gateway.sh
```

## Method 2: Direct Lambda Testing (Validate Lambda Function)

Test the Lambda function directly to ensure it's working:

```bash
# Test the calculator Lambda directly
aws lambda invoke \
    --function-name "a208194-calculator-mcp-server" \
    --payload '{
        "jsonrpc": "2.0",
        "method": "tools/list",
        "id": 1
    }' \
    --region us-east-1 \
    lambda-direct-test.json

cat lambda-direct-test.json | jq '.'
```

```bash
# Test a calculation directly
aws lambda invoke \
    --function-name "a208194-calculator-mcp-server" \
    --payload '{
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
            "name": "add",
            "arguments": {"a": 5, "b": 3}
        },
        "id": 2
    }' \
    --region us-east-1 \
    lambda-calc-test.json

cat lambda-calc-test.json | jq '.'
```

## Method 3: Gateway Target Status Check

Check if the target is properly configured:

```bash
# List all targets in your gateway
aws bedrock-agent describe-agent \
    --agent-id "a208194-askjulius-agentcore-gateway-mcp-iam" \
    --region us-east-1 | jq '.agent.targets'
```

## Method 4: Console Testing

1. Go to **AWS Console → Bedrock → Agent Core → Gateways**
2. Click on `a208194-askjulius-agentcore-gateway-mcp-iam`
3. Go to **Targets** tab
4. Verify `target-direct-calculator-lambda` shows as **Active**
5. Click **Test** button if available
6. Try sample inputs:
   - "Calculate 10 plus 5"
   - "What is 8 divided by 2?"
   - "Find the square root of 25"

## Method 5: CloudWatch Logs Monitoring

Monitor execution in real-time:

```bash
# Watch calculator Lambda logs
aws logs tail /aws/lambda/a208194-calculator-mcp-server \
    --region us-east-1 \
    --follow

# In another terminal, run your tests
```

## Expected Successful Responses:

### Direct Lambda Test (tools/list):
```json
{
  "jsonrpc": "2.0",
  "result": {
    "tools": [
      {
        "name": "add",
        "description": "Add two numbers together...",
        "inputSchema": {...}
      },
      ...
    ]
  },
  "id": 1
}
```

### Direct Lambda Test (calculation):
```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Addition: 5 + 3 = 8"
      }
    ],
    "isError": false
  },
  "id": 2
}
```

### Gateway Response Format:
```json
{
  "sessionId": "test-session-001",
  "completion": "The calculation result is 8.",
  "trace": {...},
  "citations": [...]
}
```

## Troubleshooting Common Issues:

### Issue 1: Target Not Active
- Check Lambda permissions
- Verify service role has `lambda:InvokeFunction` permission
- Ensure Lambda is in same region

### Issue 2: Schema Validation Errors
- Verify inline schema uses JSON double quotes
- Check all required fields (name, description, inputSchema) are present
- Validate JSON structure

### Issue 3: Lambda Execution Errors
- Check CloudWatch logs for Lambda errors
- Verify Lambda function code is deployed correctly
- Test Lambda directly first

### Issue 4: Gateway Communication Issues
- Check IAM permissions
- Verify MCP protocol implementation in Lambda
- Ensure proper JSON-RPC 2.0 format

## Quick Validation Checklist:

- [ ] Target shows as "Active" in console
- [ ] Direct Lambda test returns tools list
- [ ] Direct Lambda calculation test works
- [ ] Gateway invoke-agent returns response
- [ ] CloudWatch logs show successful execution
- [ ] Error handling works (division by zero test)
- [ ] All 10 calculator tools are available
- [ ] MCP protocol communication successful