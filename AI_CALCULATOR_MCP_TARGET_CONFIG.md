# AI Calculator Lambda MCP Target Configuration

## For AWS Console - Agent Core Gateway Target Creation

### Target Configuration:
- **Target Name**: `target-lambda-direct-ai-calculator-mcp`
- **Target Description**: `AI-powered calculator using Bedrock Claude for natural language mathematical operations`
- **Target Type**: `MCP Server`

### MCP Endpoint Configuration:
- **MCP Server Type**: `Lambda`
- **Lambda Function**: `a208194-ai-calculator-mcp-server`
- **Lambda ARN**: `arn:aws:lambda:us-east-1:818565325759:function:a208194-ai-calculator-mcp-server`

### Tool Schema (Inline):
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

## Console UI Fields Mapping:

### Step 1: Target Basic Info
- **Target Name**: `target-lambda-direct-ai-calculator-mcp`
- **Description**: `AI-powered calculator using Bedrock Claude for natural language mathematical operations`

### Step 2: MCP Server Configuration  
- **Server Type**: Select `Lambda`
- **Lambda Function**: Select `a208194-ai-calculator-mcp-server` from dropdown
- **OR Lambda ARN**: `arn:aws:lambda:us-east-1:818565325759:function:a208194-ai-calculator-mcp-server`

### Step 3: Tool Definition
- **Schema Type**: `Inline`
- **Tools Schema**: Paste the JSON schema above

### Step 4: Authentication
- **Outbound Auth**: `AWS IAM`

## Expected Tool Names After Creation:
- `target-lambda-direct-ai-calculator-mcp___ai_calculate`
- `target-lambda-direct-ai-calculator-mcp___explain_calculation`  
- `target-lambda-direct-ai-calculator-mcp___solve_word_problem`

## Test Examples After Setup:

### Natural Language Calculation:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call", 
  "params": {
    "name": "target-lambda-direct-ai-calculator-mcp___ai_calculate",
    "arguments": {
      "query": "What is 15% of $50,000?"
    }
  }
}
```

### Mathematical Explanation:
```json
{
  "jsonrpc": "2.0", 
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "target-lambda-direct-ai-calculator-mcp___explain_calculation",
    "arguments": {
      "calculation": "compound interest formula"
    }
  }
}
```

### Word Problem Solving:
```json
{
  "jsonrpc": "2.0",
  "id": 3, 
  "method": "tools/call",
  "params": {
    "name": "target-lambda-direct-ai-calculator-mcp___solve_word_problem", 
    "arguments": {
      "problem": "If I invest $1000 at 7% annual interest for 10 years with compound interest, how much will I have?"
    }
  }
}
```