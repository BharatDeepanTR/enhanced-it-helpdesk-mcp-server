# Step-by-Step Guide: Add MCP Target via Bedrock Console

## 🎯 STEP 1: Add MCP Target to Existing Gateway

### Navigate to Gateway
1. Go to AWS Console: https://console.aws.amazon.com/bedrock/home?region=us-east-1#/agent-core/gateways
2. Find your gateway: `a208194-askjulius-agentcore-gateway-mcp-iam`
3. Click on the gateway name to open details

### Add New Target
4. In the gateway details page, click **"Add Target"** button
5. Fill out the target configuration:

**Target Basic Info:**
- **Target name**: `target-lambda-direct-ai-bedrock-calculator-mcp`
- **Target description**: `AI-powered Bedrock calculator using Claude for natural language mathematical operations`

**Target Type Selection:**
- Select **"MCP server"** (this is where the OAuth issue occurs)

### 🔧 WORKAROUND for OAuth Client Issue

**Option A: Browser-Based Workaround**
1. **Try Incognito/Private Mode**: Open console in private browsing
2. **Clear Cache**: Clear browser cache and cookies for AWS console
3. **Different Browser**: Try Chrome → Firefox or Firefox → Chrome
4. **Refresh Page**: Refresh the "Add Target" page multiple times

**Option B: Target Creation Order Workaround**
1. **Create as REST API first**: Select "REST API" instead of "MCP server"
2. **Save as draft**: Save the target configuration
3. **Edit target**: Go back and edit the target to change to "MCP server"
4. **Check auth options**: See if IAM Role becomes available

**Option C: Console Session Reset**
1. **Sign out** of AWS Console completely
2. **Sign back in** 
3. **Navigate directly** to the gateway page
4. **Try adding target** again

### 🎯 STEP 2: Configure MCP Endpoint (When OAuth Issue Resolved)

**MCP Server Configuration:**
- **Server Type**: Select **"Lambda ARN"**
- **Lambda Function**: Select `a208194-ai-bedrock-calculator-mcp-server` from dropdown
- **OR Lambda ARN**: `arn:aws:lambda:us-east-1:818565325759:function:a208194-ai-bedrock-calculator-mcp-server`

**Outbound Authentication:**
- **Select**: **"IAM Role"** (this is what we want, not OAuth client)

**Tool Schema Configuration:**
- **Schema Type**: Select **"Inline"**
- **Tools Schema**: Paste this JSON array:

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

### 🎯 STEP 3: Test End-to-End Functionality

#### Test 1: Verify Target Creation
1. **Check target list**: Ensure target appears in gateway targets
2. **Verify status**: Target should show "Active" status
3. **Check tools**: Verify 3 tools are available:
   - `target-lambda-direct-ai-bedrock-calculator-mcp___ai_calculate`
   - `target-lambda-direct-ai-bedrock-calculator-mcp___explain_calculation`
   - `target-lambda-direct-ai-bedrock-calculator-mcp___solve_word_problem`

#### Test 2: Direct Lambda Testing
```bash
# Test the Lambda function directly first
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
  response.json && cat response.json
```

#### Test 3: Gateway Integration Testing
Use your enterprise MCP client to test:

**Natural Language Math:**
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

**Mathematical Explanation:**
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "target-lambda-direct-ai-bedrock-calculator-mcp___explain_calculation",
    "arguments": {
      "calculation": "compound interest formula"
    }
  }
}
```

**Word Problem Solving:**
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "target-lambda-direct-ai-bedrock-calculator-mcp___solve_word_problem",
    "arguments": {
      "problem": "Sarah has 24 apples and wants to distribute them equally among 6 friends. How many apples will each friend get, and how many will be left over?"
    }
  }
}
```

### 🎯 STEP 4: Monitor AWS CLI Command Availability

#### Create AWS CLI Monitoring Script
```bash
# Check for CLI updates monthly
#!/bin/bash
echo "Checking for Agent Core Gateway CLI commands..."
aws bedrock-agent help | grep -i "agent-core" || echo "Not available yet"
aws bedrock-agent-runtime help | grep -i "agent-core" || echo "Not available yet"
aws --version
```

#### Set up AWS CLI Update Monitoring
```bash
# Add to crontab for monthly checks
# 0 9 1 * * /path/to/check-cli-updates.sh
```

## 🚨 If OAuth Issue Persists

### Escalation Options:
1. **AWS Support Case**: Create support case specifically about "Agent Core Gateway MCP target OAuth client forced selection"
2. **AWS Forums**: Post in AWS Developer Forums
3. **Alternative IAM Approach**: Try creating target with different IAM permissions
4. **Console Region Switch**: Try creating target in different region temporarily

### Emergency Workaround:
If OAuth client is absolutely forced:
1. **Create OAuth client** as temporary measure
2. **Document the setup** for future conversion
3. **Monitor for console updates** that allow IAM Role selection

## Expected Tool Names After Success:
- `target-lambda-direct-ai-bedrock-calculator-mcp___ai_calculate`
- `target-lambda-direct-ai-bedrock-calculator-mcp___explain_calculation`
- `target-lambda-direct-ai-bedrock-calculator-mcp___solve_word_problem`

## Verification Commands:
```bash
# Check if target is accessible via IAM role policies
aws iam get-role-policy \
  --role-name a208194-askjulius-agentcore-gateway \
  --policy-name LambdaInvokePolicy

# Verify Lambda exists
aws lambda get-function \
  --function-name a208194-ai-bedrock-calculator-mcp-server \
  --region us-east-1
```