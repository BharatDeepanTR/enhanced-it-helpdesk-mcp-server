# AWS Console MCP Target Creation - Step by Step

## Current Console UI Fields (Based on Your Screenshot)

### Step 1: Basic Target Configuration
✅ **Target name**: `target-lambda-direct-ai-calculator-mcp`
✅ **Target description**: `AI-powered calculator using Bedrock Claude for natural language mathematical operations`
✅ **Target type**: Select `MCP server`

### Step 2: MCP Server Configuration
The console shows these options for MCP server:
- **Lambda ARN**: ✅ Select this option (not the others)
- REST API
- Integrations

### Step 3: MCP Endpoint Configuration
When you select "Lambda ARN", you should see:
- **Lambda ARN field**: Enter `arn:aws:lambda:us-east-1:818565325759:function:a208194-ai-calculator-mcp-server`
- OR **Lambda Function Dropdown**: Select `a208194-ai-calculator-mcp-server` if available

### Step 4: Outbound Auth Configuration
✅ **Select**: `IAM Role` (not OAuth client, API key, or No authorization)

### Step 5: Tool Schema Definition
After setting up the MCP endpoint, you should see a section for tool schema. Use this inline schema:

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

## Important Notes:

1. **First Create the Lambda**: Before adding this target, ensure the Lambda function `a208194-ai-calculator-mcp-server` exists
2. **IAM Permissions**: The gateway's service role must have permission to invoke this Lambda
3. **MCP Endpoint = Lambda ARN**: The console is asking for the MCP endpoint, which in our case is the Lambda function ARN

## Next Steps:

### 1. Create AI Calculator Lambda First
```bash
# Navigate to Lambda console and create function:
# Function name: a208194-ai-calculator-mcp-server
# Runtime: Python 3.12
# Upload: ai-calculator-mcp-lambda.zip
```

### 2. Then Add Target to Gateway
Follow the steps above in the AWS Console.

### 3. Test the Integration
After creation, test with:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "target-lambda-direct-ai-calculator-mcp___ai_calculate",
    "arguments": {
      "query": "What is 25% of $80,000?"
    }
  }
}
```

## Console UI Flow Summary:
1. Target name + description ✅
2. Target type: MCP server ✅
3. MCP endpoint type: Lambda ARN ✅
4. Lambda ARN: `arn:aws:lambda:us-east-1:818565325759:function:a208194-ai-calculator-mcp-server` ✅
5. Outbound auth: IAM Role ✅
6. Tool schema: Paste JSON array ✅
7. Create target ✅