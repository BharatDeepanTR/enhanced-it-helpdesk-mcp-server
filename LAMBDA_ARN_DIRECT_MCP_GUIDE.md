# 🎯 Lambda ARN Direct MCP Server Setup Guide

## 🚀 **SIMPLIFIED APPROACH: Bypass OAuth Issues**

Instead of dealing with OAuth client authentication problems, use **Lambda ARN directly as MCP server type**. This leverages the gateway's existing service role for Lambda invocation.

## ✅ **Prerequisites Confirmed:**
- Gateway exists: `a208194-askjulius-agentcore-gateway-mcp-iam` ✅
- Service role: `a208194-askjulius-agentcore-gateway` ✅ 
- Lambda ready: `a208194-ai-bedrock-calculator-mcp-server` ✅ (MCP-compatible, 4,497 bytes)
- Lambda permissions: Service role can invoke Lambda ✅

## 📋 **Console Steps (Simplified)**

### 1. Navigate to Gateway
```
https://console.aws.amazon.com/bedrock/home?region=us-east-1#/agent-core/gateways
```
Find: `a208194-askjulius-agentcore-gateway-mcp-iam`

### 2. Add Target (Click "Add Target")

#### **Basic Target Info:**
- **Target Name**: `target-lambda-direct-ai-bedrock-calculator-mcp`
- **Description**: `AI-powered Bedrock calculator using Claude for natural language mathematical operations`

#### **Target Type Selection:**
- **Target Type**: Select `MCP server` ✅

#### **MCP Endpoint Configuration:**
- **Server Type**: Select `Lambda ARN` ✅ *(NOT REST API, NOT Integrations)*
- **Lambda Function**: Select `a208194-ai-bedrock-calculator-mcp-server` from dropdown
- **OR Lambda ARN**: `arn:aws:lambda:us-east-1:818565325759:function:a208194-ai-bedrock-calculator-mcp-server`

#### **Authentication:**
- **Outbound Auth**: Should automatically use gateway's service role ✅
- **NO OAuth client selection needed!** 🎉

#### **Tool Schema:**
- **Schema Type**: `Inline`
- **Tools Schema**: Paste the AI calculator schema (see below)

## 🔑 **AI Calculator Tool Schema** (Copy-Paste)
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

## 🎯 **Why This Approach Works Better:**

1. **No OAuth Complexity**: Gateway service role handles Lambda invocation
2. **Direct Lambda Execution**: Bypasses intermediate authentication layers
3. **Existing Permissions**: Service role already has Lambda invoke permissions
4. **MCP Compatible**: Lambda properly handles MCP JSON-RPC format
5. **Proven Architecture**: Other targets use same pattern

## 🚀 **Expected Result:**

After creation, you'll have these tools available:
- `target-lambda-direct-ai-bedrock-calculator-mcp___ai_calculate`
- `target-lambda-direct-ai-bedrock-calculator-mcp___explain_calculation`
- `target-lambda-direct-ai-bedrock-calculator-mcp___solve_word_problem`

## 🧪 **Test After Creation:**

Use your enterprise MCP client to test:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "target-lambda-direct-ai-bedrock-calculator-mcp___ai_calculate",
    "arguments": {
      "query": "What is 25% of $80,000?"
    }
  }
}
```

Expected: AI-powered natural language math response with Bedrock Claude! 🎉

## 💡 **Key Insight:**

**Lambda ARN as MCP server = Gateway service role authentication**  
This completely sidesteps the OAuth client forced selection issue!