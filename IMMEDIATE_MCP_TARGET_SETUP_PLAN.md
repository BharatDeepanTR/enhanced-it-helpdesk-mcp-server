# 🎯 IMMEDIATE ACTION PLAN: Add AI Bedrock Calculator MCP Target

## ✅ CONFIRMED: Lambda is Ready
- **Function**: `a208194-ai-bedrock-calculator-mcp-server`
- **Runtime**: `python3.14` 
- **Status**: `Active`
- **Last Modified**: `2025-11-16T12:12:21.202+0000`

## 🚀 STEP 1: Navigate to Gateway Console

### Quick Link:
```
https://console.aws.amazon.com/bedrock/home?region=us-east-1#/agent-core/gateways
```

### Manual Navigation:
1. AWS Console → Services → Amazon Bedrock
2. Left sidebar → Agent Core → Gateways
3. Find: `a208194-askjulius-agentcore-gateway-mcp-iam`
4. Click on gateway name

## 🎯 STEP 2: Add MCP Target

### In Gateway Details Page:
1. Click **"Add Target"** button
2. Fill out configuration:

**Basic Configuration:**
```
Target name: target-lambda-direct-ai-bedrock-calculator-mcp
Target description: AI-powered Bedrock calculator using Claude for natural language mathematical operations
```

**Target Type:**
- Select: **"MCP server"**

### 🔧 OAuth Issue Workarounds (Try These in Order):

#### Workaround A: Browser Reset
1. **Open Incognito/Private Window**
2. **Clear Browser Cache/Cookies** for AWS Console
3. **Try Different Browser** (Chrome ↔ Firefox)

#### Workaround B: Creation Sequence
1. **Refresh the Add Target page** multiple times
2. **Start typing in auth dropdown** (might show hidden options)
3. **Tab through form fields** to see if IAM Role appears

#### Workaround C: Alternative Path
1. **Create as "REST API" first** (temporary)
2. **Save target configuration**
3. **Edit target** → Change to "MCP server"
4. **Check if IAM Role becomes available**

## 🎯 STEP 3: Configure MCP Endpoint (When Auth Fixed)

**MCP Server Configuration:**
```
Server Type: Lambda ARN
Lambda Function: a208194-ai-bedrock-calculator-mcp-server
OR Lambda ARN: arn:aws:lambda:us-east-1:818565325759:function:a208194-ai-bedrock-calculator-mcp-server
```

**Outbound Authentication:**
```
Select: IAM Role (NOT OAuth client)
```

**Tool Schema (Inline JSON):**
```json
[
  {
    "name": "ai_calculate",
    "description": "AI-powered calculator that can handle natural language math queries, complex calculations, and provide step-by-step explanations",
    "inputSchema": {
      "type": "object",
      "properties": {
        "query": {
          "type": "string",
          "description": "Natural language math query (e.g., 'What is 15% of $50,000?', 'Calculate compound interest for 5 years at 4.5%')"
        }
      },
      "required": ["query"]
    }
  },
  {
    "name": "explain_calculation",
    "description": "Explain mathematical concepts and provide step-by-step solutions for given calculations",
    "inputSchema": {
      "type": "object",
      "properties": {
        "calculation": {
          "type": "string",
          "description": "Mathematical expression or problem to explain (e.g., '25 + 4', 'quadratic formula')"
        }
      },
      "required": ["calculation"]
    }
  },
  {
    "name": "solve_word_problem",
    "description": "Solve mathematical word problems with detailed explanations",
    "inputSchema": {
      "type": "object",
      "properties": {
        "problem": {
          "type": "string",
          "description": "Mathematical word problem to solve"
        }
      },
      "required": ["problem"]
    }
  }
]
```

## 🔬 STEP 4: Test Direct Lambda First

Before gateway testing, verify Lambda works:

### Test Command:
```bash
aws lambda invoke \
  --function-name a208194-ai-bedrock-calculator-mcp-server \
  --region us-east-1 \
  --payload '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "ai_calculate",
      "arguments": {
        "query": "What is 25% of $80,000?"
      }
    }
  }' \
  response.json
```

### Check Response:
```bash
cat response.json
```

**Expected Response Format:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "25% of $80,000 is $20,000..."
      }
    ]
  }
}
```

## 🎯 STEP 5: Test Gateway Integration

After target creation, test with your enterprise MCP client:

### Test 1: Natural Language Math
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "target-lambda-direct-ai-bedrock-calculator-mcp___ai_calculate",
    "arguments": {
      "query": "If I invest $10,000 at 7% annual interest compounded annually for 5 years, how much will I have?"
    }
  }
}
```

### Test 2: Mathematical Explanation
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "target-lambda-direct-ai-bedrock-calculator-mcp___explain_calculation",
    "arguments": {
      "calculation": "compound interest formula A = P(1 + r)^t"
    }
  }
}
```

### Test 3: Word Problem
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "target-lambda-direct-ai-bedrock-calculator-mcp___solve_word_problem",
    "arguments": {
      "problem": "A company's revenue increased from $500,000 to $650,000. What was the percentage increase?"
    }
  }
}
```

## 🚨 If OAuth Issue Persists - Emergency Actions:

### 1. Check Service Role Permissions:
```bash
aws iam get-role-policy \
  --role-name a208194-askjulius-agentcore-gateway \
  --policy-name LambdaInvokePolicy
```

### 2. Verify Lambda Permissions:
```bash
aws lambda get-policy \
  --function-name a208194-ai-bedrock-calculator-mcp-server \
  --region us-east-1 2>/dev/null || echo "No resource-based policy found"
```

### 3. AWS Support Escalation:
- **Issue**: "Agent Core Gateway MCP target forces OAuth client, cannot select IAM Role"
- **Impact**: "Cannot configure Lambda-based MCP targets with proper authentication"
- **Expected**: "IAM Role should be selectable for Lambda MCP endpoints"

## 📊 SUCCESS METRICS:

### Target Created Successfully:
- [ ] Target appears in gateway target list
- [ ] Target status shows "Active"
- [ ] 3 tools are visible:
  - `target-lambda-direct-ai-bedrock-calculator-mcp___ai_calculate`
  - `target-lambda-direct-ai-bedrock-calculator-mcp___explain_calculation`
  - `target-lambda-direct-ai-bedrock-calculator-mcp___solve_word_problem`

### Lambda Integration Working:
- [ ] Direct Lambda test returns MCP-formatted response
- [ ] Gateway routing works via enterprise client
- [ ] AI calculations provide accurate results
- [ ] Mathematical explanations are detailed and correct

## 💡 Pro Tips:
1. **Copy-paste tool schema** exactly as provided (JSON syntax is critical)
2. **Test Lambda directly first** before troubleshooting gateway
3. **Screenshot OAuth issue** for AWS Support case
4. **Document exact steps** that reproduce the authentication problem

Ready to proceed? Start with Step 1 and let me know when you hit the OAuth authentication issue!