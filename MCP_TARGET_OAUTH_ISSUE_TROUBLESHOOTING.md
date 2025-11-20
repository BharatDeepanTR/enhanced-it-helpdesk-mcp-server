# MCP Target OAuth Client Issue - Troubleshooting Guide

## Problem Description
When selecting "MCP Server" as target type, the console defaults to "OAuth client" for outbound authentication and doesn't allow selection of "IAM Role".

## Potential Causes & Solutions

### 1. Console Region Issue
**Check**: Ensure you're in the correct region (us-east-1)
- AWS Console → Top right → Region selector → US East (N. Virginia)

### 2. Service Role Permissions Issue
**Check**: Verify the gateway service role has proper permissions

#### Required Service Role Policies:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "bedrock.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
```

#### Required Permissions:
- `AmazonBedrockFullAccess`
- `AWSLambdaExecute` 
- Inline policy for Lambda invocation

### 3. Lambda Function Prerequisites
**Action**: Create the Lambda function FIRST before adding as MCP target

```bash
# Lambda Creation Steps:
# 1. Go to AWS Lambda Console
# 2. Create function: a208194-ai-calculator-mcp-server
# 3. Runtime: Python 3.12
# 4. Upload: ai-calculator-mcp-lambda.zip
# 5. Configure proper execution role with Bedrock permissions
```

### 4. Gateway State Issue
**Check**: Verify gateway exists and is in correct state

```bash
# List existing gateways
aws bedrock-agent-runtime list-agent-core-gateways --region us-east-1

# Get gateway details
aws bedrock-agent-runtime get-agent-core-gateway \
  --gateway-name "a208194-askjulius-agentcore-gateway-mcp-iam" \
  --region us-east-1
```

### 5. Alternative Approach: Create Target via CLI
If console continues to force OAuth, use AWS CLI:

```bash
# Create target via CLI (avoiding console OAuth issue)
aws bedrock-agent-runtime create-agent-core-gateway-target \
  --gateway-name "a208194-askjulius-agentcore-gateway-mcp-iam" \
  --region us-east-1 \
  --target-name "target-lambda-direct-ai-calculator-mcp" \
  --target-description "AI-powered calculator using Bedrock Claude" \
  --target-configuration '{
    "type": "MCP",
    "mcp": {
      "lambda": {
        "lambdaArn": "arn:aws:lambda:us-east-1:818565325759:function:a208194-ai-calculator-mcp-server",
        "toolSchema": {
          "inlinePayload": [
            {
              "name": "ai_calculate",
              "description": "AI-powered calculator for natural language math queries",
              "inputSchema": {
                "type": "object",
                "properties": {
                  "query": {
                    "type": "string",
                    "description": "Natural language math query"
                  }
                },
                "required": ["query"]
              }
            }
          ]
        }
      }
    }
  }' \
  --outbound-auth-config '{"type": "AWS_IAM"}'
```

## Immediate Next Steps

### Step 1: Verify Prerequisites
1. **Check Gateway Exists**:
   ```bash
   aws bedrock-agent-runtime list-agent-core-gateways --region us-east-1
   ```

2. **Create Lambda Function**:
   - Function name: `a208194-ai-calculator-mcp-server`
   - Runtime: Python 3.12
   - Upload: `ai-calculator-mcp-lambda.zip`

### Step 2: Try Alternative Console Approach
1. Try creating target as **"Lambda ARN"** type first (not MCP Server)
2. See if IAM Role option becomes available
3. Then modify target to MCP format

### Step 3: Use CLI Workaround
If console continues to force OAuth, use the CLI command above to create the target with proper IAM authentication.

## Console UI Behavior Analysis

The OAuth client default suggests:
- Console might be assuming external MCP servers (not Lambda-based)
- Lambda-based MCP targets might need different UI flow
- Potential console bug or missing feature for Lambda MCP targets

## Recommended Action Plan

1. **First**: Create the Lambda function `a208194-ai-calculator-mcp-server`
2. **Then**: Try CLI approach for target creation
3. **Finally**: Test the target functionality regardless of how it was created

The key is getting the target created with IAM authentication - the method (console vs CLI) is less important than the result.