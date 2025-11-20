# AI Calculator MCP Lambda

## Overview
This Lambda function provides AI-powered calculator capabilities through the MCP protocol by internally calling AWS Bedrock Claude models.

## Features
- **Natural Language Math**: "What is 15% of $50,000?"
- **Step-by-step Explanations**: Detailed mathematical reasoning
- **Word Problem Solving**: Complex mathematical scenarios
- **MCP Protocol Compatible**: Works with Agent Core Gateway

## MCP Tools Provided
1. `ai_calculate` - Natural language math queries
2. `explain_calculation` - Step-by-step explanations  
3. `solve_word_problem` - Mathematical word problems

## Deployment
1. Upload as Lambda function: `a208194-ai-calculator-mcp-server`
2. Runtime: Python 3.11
3. Handler: `lambda_function.lambda_handler`
4. Timeout: 60 seconds
5. Memory: 512 MB

## Required IAM Permissions
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "bedrock:InvokeModel"
            ],
            "Resource": [
                "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-5-sonnet-20241022-v2:0"
            ]
        }
    ]
}
```

## Usage Examples

### Via Gateway (MCP Protocol)
```json
{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
        "name": "target-lambda-direct-ai-calculator-mcp___ai_calculate",
        "arguments": {
            "query": "Calculate the monthly payment for a $50,000 loan at 4.5% annual interest for 5 years"
        }
    }
}
```

### Direct Invocation
```json
{
    "query": "What is 25 plus 4 and explain the process?"
}
```

## Response Format
Returns MCP-compatible responses with detailed mathematical explanations and step-by-step solutions.