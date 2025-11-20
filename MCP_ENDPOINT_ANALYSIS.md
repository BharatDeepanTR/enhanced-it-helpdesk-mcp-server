# MCP Endpoint Configuration Analysis

## Current Gateway Script MCP Endpoint Structure ✅

The `create-agentcore-gateway.sh` script **already includes** the correct MCP Endpoint configuration:

```json
{
  "targetConfiguration": {
    "type": "MCP",                    // ← Specifies this is an MCP Server target
    "mcp": {                          // ← MCP Endpoint Configuration Section
      "lambda": {                     // ← MCP Server Type: Lambda
        "lambdaArn": "$LAMBDA_ARN",   // ← MCP Endpoint Location (Lambda ARN)
        "toolSchema": {               // ← Tool definitions for this MCP server
          "inlinePayload": [...]      // ← Inline schema definition
        }
      }
    }
  }
}
```

## Console UI Mapping for MCP Target Creation

When creating the target in AWS Console, the script's JSON structure maps to these UI fields:

### Target Type Selection:
- **Target Type**: `MCP Server` ✅

### MCP Endpoint Configuration:
- **Server Type**: `Lambda` ✅ (from `"mcp": { "lambda": {...} }`)
- **Lambda Function**: `a208194-ai-calculator-mcp-server` ✅ (from `lambdaArn`)
- **Lambda ARN**: `arn:aws:lambda:us-east-1:818565325759:function:a208194-ai-calculator-mcp-server` ✅

### Tool Schema Definition:
- **Schema Type**: `Inline` ✅ (from `"inlinePayload"`)
- **Tools Definition**: JSON array of tool objects ✅

## What Each Target's MCP Endpoint Represents:

### 1. Calculator MCP Server
- **Endpoint**: `arn:aws:lambda:us-east-1:818565325759:function:a208194-calculator-mcp-server`
- **Tools Provided**: add, subtract, multiply, divide, power, sqrt
- **Purpose**: Structured mathematical operations

### 2. AI Calculator MCP Server  
- **Endpoint**: `arn:aws:lambda:us-east-1:818565325759:function:a208194-ai-calculator-mcp-server`
- **Tools Provided**: ai_calculate, explain_calculation, solve_word_problem
- **Purpose**: Natural language mathematical operations with AI

### 3. Application Details MCP Server
- **Endpoint**: `arn:aws:lambda:us-east-1:818565325759:function:a208194-mcp-application-details-server`
- **Tools Provided**: get_application_details
- **Purpose**: Asset information lookup

## Manual Console Creation Steps (if script fails):

### Step 1: Create Target
1. Go to: AWS Console → Bedrock → Agent Core → Gateways → [Gateway] → Targets
2. Click "Add Target"
3. **Target Name**: `target-lambda-direct-ai-calculator-mcp`
4. **Description**: `AI-powered calculator using Bedrock Claude for natural language mathematical operations`

### Step 2: Configure MCP Endpoint
5. **Target Type**: Select `MCP Server`
6. **Server Type**: Select `Lambda`  
7. **Lambda Function**: Select `a208194-ai-calculator-mcp-server` from dropdown
   - OR manually enter ARN: `arn:aws:lambda:us-east-1:818565325759:function:a208194-ai-calculator-mcp-server`

### Step 3: Define Tools
8. **Schema Type**: Select `Inline`
9. **Tools Schema**: Paste the tools JSON array (see AI_CALCULATOR_MCP_TARGET_CONFIG.md)

### Step 4: Authentication  
10. **Outbound Authentication**: Select `AWS IAM`
11. Click "Create Target"

## Verification Commands:

After target creation, verify the MCP endpoint is working:

```bash
# List gateway targets
aws bedrock-agent-runtime list-agent-core-gateway-targets \
  --gateway-name "a208194-askjulius-agentcore-gateway-mcp-iam" \
  --region us-east-1

# Test AI calculator tool
aws bedrock-agent-runtime invoke-agent-core-gateway \
  --gateway-name "a208194-askjulius-agentcore-gateway-mcp-iam" \
  --region us-east-1 \
  --body '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "target-lambda-direct-ai-calculator-mcp___ai_calculate",
      "arguments": {
        "query": "What is 25% of $80,000?"
      }
    }
  }'
```

## Key Insight:
✅ The script already has the **complete MCP Endpoint configuration**
✅ Each `lambdaArn` IS the MCP endpoint location
✅ The `"mcp": { "lambda": {...} }` structure defines how to reach each MCP server
✅ No additional endpoint configuration needed - the script is comprehensive