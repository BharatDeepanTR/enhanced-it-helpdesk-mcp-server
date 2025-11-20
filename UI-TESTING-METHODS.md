# Alternative Testing Methods for Calculator Lambda Target
# No terminal/encoding issues - All UI and web-based methods

## 🌐 Method 1: AWS Lambda Console Testing
### Direct Lambda Function Testing

1. **Go to AWS Console → Lambda → Functions**
2. **Click on:** `a208194-calculator-mcp-server`
3. **Go to "Test" tab**
4. **Create new test event:**
   - Event name: `MCP-Tools-List`
   - Template: `Hello World` (then replace content)
   
5. **Test Event JSON:**
```json
{
    "jsonrpc": "2.0",
    "method": "tools/list",
    "id": 1
}
```

6. **Click "Test"** - Should return list of 10 calculator tools

7. **Create second test event:**
   - Event name: `Calculator-Addition`
   - Content:
```json
{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
        "name": "add",
        "arguments": {
            "a": 5,
            "b": 3
        }
    },
    "id": 2
}
```

8. **Expected Results:**
   - ✅ Tools list: JSON with 10 tools (add, subtract, multiply, etc.)
   - ✅ Addition: "Addition: 5 + 3 = 8"

---

## 🎯 Method 2: Bedrock Agent Core Gateway Console Testing  
### Gateway Target Status and Testing

1. **Go to AWS Console → Bedrock → Agent Core → Gateways**
2. **Click on:** `a208194-askjulius-agentcore-gateway-mcp-iam`
3. **Go to "Targets" tab**
4. **Find:** `target-direct-calculator-lambda`
5. **Check Status:** Should show "Active" with green indicator
6. **If "Test" button available:** Click to test target
7. **Try sample prompts:**
   - "Calculate 10 plus 5"
   - "What is 8 divided by 2?"
   - "Find the square root of 25"

---

## 📊 Method 3: CloudWatch Logs Monitoring
### Real-time Lambda Execution Monitoring

1. **Go to AWS Console → CloudWatch → Logs → Log groups**
2. **Find:** `/aws/lambda/a208194-calculator-mcp-server`
3. **Click on the log group**
4. **View recent log streams** 
5. **Look for:**
   - ✅ "Processing MCP method: tools/list"
   - ✅ "Executing calculator tool: add with arguments: {a: 5, b: 3}"
   - ✅ JSON-RPC 2.0 request/response logs
6. **Set up Log Insights query:**
```sql
fields @timestamp, @message
| filter @message like /MCP/
| sort @timestamp desc
| limit 20
```

---

## 🔧 Method 4: AWS CloudShell (Web-based Terminal)
### No Local Encoding Issues

1. **Go to AWS Console → CloudShell (terminal icon in top bar)**
2. **Wait for CloudShell to load**
3. **Run these commands:**
```bash
# Create test file
cat > test.json << EOF
{"jsonrpc":"2.0","method":"tools/list","id":1}
EOF

# Test Lambda
aws lambda invoke --function-name a208194-calculator-mcp-server --payload file://test.json --region us-east-1 result.json

# View result
cat result.json | jq .
```

4. **Expected:** Clean JSON response with calculator tools

---

## 🌍 Method 5: Postman/API Testing Tool
### REST API Testing (if API Gateway configured)

**If you have API Gateway in front of Lambda:**

1. **Open Postman or similar tool**
2. **Method:** POST
3. **URL:** Your API Gateway endpoint
4. **Headers:**
   - Content-Type: application/json
   - Authorization: AWS4-HMAC-SHA256 (if IAM auth)
5. **Body (raw JSON):**
```json
{
    "jsonrpc": "2.0",
    "method": "tools/list",
    "id": 1
}
```

---

## 🎮 Method 6: Bedrock Agents Playground
### End-to-End Integration Testing

1. **Go to AWS Console → Bedrock → Agents**
2. **Create test agent or use existing agent**
3. **Configure agent to use your Gateway**
4. **Test in Playground with natural language:**
   - "I need to calculate 15 plus 7"
   - "What's 20 divided by 4?"
   - "Calculate the square root of 16"
5. **Verify:** Agent routes to your calculator target

---

## 📱 Method 7: AWS CLI from Different Environment
### Alternative CLI Environment

**Try from:**
- ✅ **AWS CloudShell** (web-based, no encoding issues)
- ✅ **Different terminal** (Command Prompt instead of WSL)
- ✅ **Linux EC2 instance**
- ✅ **Mac/Linux local machine**

---

## 🔍 Method 8: Gateway Integration Testing
### Test Gateway Without Direct Lambda Calls

1. **Create simple test application using AWS SDK**
2. **Use Bedrock Agent Runtime API:**
```python
import boto3

client = boto3.client('bedrock-agent-runtime')

response = client.invoke_agent(
    agentId='a208194-askjulius-agentcore-gateway-mcp-iam',
    sessionId='test-session-123',
    inputText='Calculate 5 plus 3'
)
```

---

## 📋 Method 9: Manual Console Verification Checklist
### Step-by-Step Gateway Status Check

**Gateway Configuration:**
- [ ] Gateway exists: `a208194-askjulius-agentcore-gateway-mcp-iam`
- [ ] Gateway status: Active
- [ ] Service role configured correctly
- [ ] IAM authentication enabled

**Target Configuration:**
- [ ] Target exists: `target-direct-calculator-lambda`
- [ ] Target status: Active (green indicator)
- [ ] Lambda ARN correct: `arn:aws:lambda:us-east-1:818565325759:function:a208194-calculator-mcp-server`
- [ ] Target type: MCP
- [ ] Inline schema populated (10 tools)
- [ ] Authorization: IAM

**Lambda Function:**
- [ ] Function exists and is Active
- [ ] Runtime: Python 3.10+
- [ ] Handler: lambda_function.lambda_handler
- [ ] Code size > 0 KB
- [ ] No errors in recent executions

---

## 🎯 Quick Win: Start with Method 1 (Lambda Console)
**This is the fastest way to validate:**

1. **Lambda Console → Test tab**
2. **Create MCP test event**
3. **If this works → Lambda is good**
4. **Then check Gateway status (Method 2)**
5. **If Gateway shows Active → Integration is working!**

The terminal encoding issue is **purely local** - your Lambda and Gateway integration can be perfectly functional even if local testing fails! 🚀