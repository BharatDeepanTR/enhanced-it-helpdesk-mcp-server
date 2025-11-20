#!/bin/bash
# Enhanced Gateway Configuration with both Lambda MCP and Bedrock Model targets
# This demonstrates hybrid approach: structured tools + AI capabilities

set -e

GATEWAY_NAME="a208194-askjulius-agentcore-gateway-mcp-iam"
SERVICE_ROLE_NAME="a208194-askjulius-agentcore-gateway"

# Lambda MCP Targets (Existing)
CALCULATOR_LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-calculator-mcp-server"
APP_DETAILS_LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-mcp-application-details-server"

# Bedrock Foundation Models
CLAUDE_MODEL_ID="anthropic.claude-3-5-sonnet-20241022-v2:0"
# Alternative models you could try:
# CLAUDE_HAIKU_MODEL_ID="anthropic.claude-3-haiku-20240307-v1:0"  # Faster, cheaper
# LLAMA_MODEL_ID="meta.llama3-2-11b-instruct-v1:0"                # Open source alternative

REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "ACCOUNT_ID_NEEDED")

echo "🚀 Creating Enhanced Bedrock Agent Core Gateway..."
echo "Gateway Name: $GATEWAY_NAME"
echo "Region: $REGION"
echo "Account ID: $ACCOUNT_ID"
echo ""

# Construct full service role ARN
SERVICE_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${SERVICE_ROLE_NAME}"

echo "📋 Configuration:"
echo "   Service Role ARN: $SERVICE_ROLE_ARN"
echo "   Calculator Lambda ARN: $CALCULATOR_LAMBDA_ARN"
echo "   Application Details Lambda ARN: $APP_DETAILS_LAMBDA_ARN"
echo "   Claude Model ID: $CLAUDE_MODEL_ID"
echo ""

# Enhanced service role creation with Bedrock model access
echo "🔍 Verifying enhanced service role..."
if aws iam get-role --role-name "$SERVICE_ROLE_NAME" >/dev/null 2>&1; then
    echo "   ✅ Service role '$SERVICE_ROLE_NAME' found"
    
    # Check if it has Bedrock model access
    echo "   🔍 Checking Bedrock model permissions..."
    
    # Add Bedrock model invoke permissions
    cat > bedrock-model-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "bedrock:InvokeModel",
                "bedrock:InvokeModelWithResponseStream"
            ],
            "Resource": [
                "arn:aws:bedrock:$REGION::foundation-model/$CLAUDE_MODEL_ID",
                "arn:aws:bedrock:$REGION::foundation-model/*"
            ]
        }
    ]
}
EOF

    aws iam put-role-policy \
        --role-name "$SERVICE_ROLE_NAME" \
        --policy-name "BedrockModelInvokePolicy" \
        --policy-document file://bedrock-model-policy.json
    
    echo "   ✅ Bedrock model permissions added"
    rm -f bedrock-model-policy.json
else
    echo "   ❌ Service role '$SERVICE_ROLE_NAME' not found"
    echo "   Please run the main gateway creation script first to create the base service role"
    exit 1
fi

# Create enhanced gateway configuration with BOTH target types
cat > enhanced-gateway-request.json << EOF
{
    "gatewayName": "$GATEWAY_NAME",
    "gatewayConfiguration": {
        "semanticSearchEnabled": true,
        "inboundAuthConfig": {
            "type": "AWS_IAM"
        },
        "serviceRoleArn": "$SERVICE_ROLE_ARN"
    },
    "targets": [
        {
            "targetName": "target-lambda-direct-calculator-mcp",
            "targetDescription": "Structured calculator Lambda with specific mathematical operations",
            "targetConfiguration": {
                "type": "MCP",
                "mcp": {
                    "lambda": {
                        "lambdaArn": "$CALCULATOR_LAMBDA_ARN",
                        "toolSchema": {
                            "inlinePayload": [
                                {
                                    "name": "add",
                                    "description": "Add two numbers together",
                                    "inputSchema": {
                                        "type": "object",
                                        "properties": {
                                            "a": {"type": "number", "description": "First number to add"},
                                            "b": {"type": "number", "description": "Second number to add"}
                                        },
                                        "required": ["a", "b"]
                                    }
                                },
                                {
                                    "name": "subtract",
                                    "description": "Subtract second number from first number",
                                    "inputSchema": {
                                        "type": "object",
                                        "properties": {
                                            "a": {"type": "number", "description": "Number to subtract from"},
                                            "b": {"type": "number", "description": "Number to subtract"}
                                        },
                                        "required": ["a", "b"]
                                    }
                                },
                                {
                                    "name": "multiply",
                                    "description": "Multiply two numbers together",
                                    "inputSchema": {
                                        "type": "object",
                                        "properties": {
                                            "a": {"type": "number", "description": "First number to multiply"},
                                            "b": {"type": "number", "description": "Second number to multiply"}
                                        },
                                        "required": ["a", "b"]
                                    }
                                },
                                {
                                    "name": "divide",
                                    "description": "Divide first number by second number",
                                    "inputSchema": {
                                        "type": "object",
                                        "properties": {
                                            "a": {"type": "number", "description": "Dividend"},
                                            "b": {"type": "number", "description": "Divisor"}
                                        },
                                        "required": ["a", "b"]
                                    }
                                }
                            ]
                        }
                    }
                }
            },
            "outboundAuthConfig": {
                "type": "AWS_IAM"
            }
        },
        {
            "targetName": "target-lambda-direct-application-details-mcp",
            "targetDescription": "Application details service for asset information lookup",
            "targetConfiguration": {
                "type": "MCP",
                "mcp": {
                    "lambda": {
                        "lambdaArn": "$APP_DETAILS_LAMBDA_ARN",
                        "toolSchema": {
                            "inlinePayload": [
                                {
                                    "name": "get_application_details",
                                    "description": "Get application details for a given asset ID",
                                    "inputSchema": {
                                        "type": "object",
                                        "properties": {
                                            "asset_id": {
                                                "type": "string",
                                                "description": "Application asset ID"
                                            }
                                        },
                                        "required": ["asset_id"]
                                    }
                                }
                            ]
                        }
                    }
                }
            },
            "outboundAuthConfig": {
                "type": "AWS_IAM"
            }
        },
        {
            "targetName": "target-bedrock-claude-calculator",
            "targetDescription": "AI-powered calculator using Claude for natural language mathematical operations, complex calculations, and explanations",
            "targetConfiguration": {
                "type": "BEDROCK_MODEL",
                "bedrockModel": {
                    "modelId": "$CLAUDE_MODEL_ID",
                    "inferenceConfiguration": {
                        "temperature": 0.1,
                        "maxTokens": 1000,
                        "topP": 0.9
                    },
                    "systemPrompt": "You are an advanced AI calculator assistant. You can:\n\n1. Perform any mathematical calculations (basic arithmetic, algebra, calculus, statistics, etc.)\n2. Explain mathematical concepts and show step-by-step solutions\n3. Handle natural language math queries like 'What is 15% of 240?' or 'Calculate the compound interest...'\n4. Convert between units, work with fractions, percentages, and scientific notation\n5. Solve equations and mathematical word problems\n6. Provide mathematical insights and verify calculations\n\nAlways:\n- Show your work step-by-step for complex calculations\n- Provide the final answer clearly\n- Explain mathematical concepts when helpful\n- Use appropriate mathematical notation\n- Double-check your calculations for accuracy\n\nFormat your responses clearly with the calculation steps and final result."
                }
            },
            "outboundAuthConfig": {
                "type": "AWS_IAM"
            }
        }
    ]
}
EOF

echo "📝 Enhanced gateway configuration created"

# Try to update the gateway (this may require using update commands instead of create)
echo ""
echo "🔄 Attempting to update gateway with Bedrock model target..."

# Method 1: Try update-agent-core-gateway if it exists
if aws bedrock-agent-runtime help 2>/dev/null | grep -q "update-agent-core-gateway"; then
    echo "   Trying Method 1: update-agent-core-gateway..."
    if aws bedrock-agent-runtime update-agent-core-gateway \
        --cli-input-json file://enhanced-gateway-request.json \
        --region "$REGION" 2>/dev/null; then
        echo "   ✅ Gateway updated successfully with Bedrock model target!"
        UPDATE_SUCCESS=true
    else
        echo "   ❌ Method 1 failed"
    fi
fi

# Method 2: Try alternative update approach
if [ "$UPDATE_SUCCESS" != "true" ]; then
    echo "   Trying Method 2: Alternative update..."
    # This might require a different approach or manual console update
    echo "   ⚠️  Automated update may not be supported"
    UPDATE_SUCCESS=false
fi

if [ "$UPDATE_SUCCESS" != "true" ]; then
    echo ""
    echo "📋 Manual Enhancement Instructions:"
    echo "=================================="
    echo ""
    echo "🌐 To add Bedrock Model Target via Console:"
    echo ""
    echo "1. Go to AWS Console → Bedrock → Agent Core → Gateways"
    echo "2. Find gateway: $GATEWAY_NAME" 
    echo "3. Click 'Edit' or 'Add Target'"
    echo ""
    echo "🎯 New Bedrock Target Configuration:"
    echo "   Target Name: target-bedrock-claude-calculator"
    echo "   Target Description: AI-powered calculator using Claude for natural language mathematical operations"
    echo "   Target Type: BEDROCK_MODEL (if available in console)"
    echo "   Model ID: $CLAUDE_MODEL_ID"
    echo ""
    echo "⚙️  Model Configuration:"
    echo "   Temperature: 0.1 (for precise calculations)"
    echo "   Max Tokens: 1000"
    echo "   Top P: 0.9"
    echo ""
    echo "📝 System Prompt:"
    cat << 'SYSTEM_PROMPT_EOF'
You are an advanced AI calculator assistant. You can:

1. Perform any mathematical calculations (basic arithmetic, algebra, calculus, statistics, etc.)
2. Explain mathematical concepts and show step-by-step solutions  
3. Handle natural language math queries like 'What is 15% of 240?' or 'Calculate the compound interest...'
4. Convert between units, work with fractions, percentages, and scientific notation
5. Solve equations and mathematical word problems
6. Provide mathematical insights and verify calculations

Always:
- Show your work step-by-step for complex calculations
- Provide the final answer clearly
- Explain mathematical concepts when helpful  
- Use appropriate mathematical notation
- Double-check your calculations for accuracy

Format your responses clearly with the calculation steps and final result.
SYSTEM_PROMPT_EOF
    echo ""
    echo "🔑 Benefits of this approach:"
    echo "   ✅ Natural language math queries"
    echo "   ✅ Complex mathematical explanations"
    echo "   ✅ Step-by-step solutions"
    echo "   ✅ Mathematical reasoning and verification"
    echo "   ✅ Handles word problems and unit conversions"
    echo ""
    echo "🎯 Your gateway will then have:"
    echo "   📊 Structured calculator (Lambda MCP): target-lambda-direct-calculator-mcp___add, etc."
    echo "   🧠 AI calculator (Bedrock): target-bedrock-claude-calculator"
    echo "   📁 Application details (Lambda MCP): target-lambda-direct-application-details-mcp___get_application_details"
fi

# Clean up
rm -f enhanced-gateway-request.json

echo ""
echo "📊 Enhanced Configuration Summary:"
echo "   Gateway: $GATEWAY_NAME"
echo "   Lambda Targets: 2 (Calculator MCP + Application Details MCP)"
echo "   Bedrock Targets: 1 (Claude Calculator AI)"
echo "   Total Capabilities: Structured tools + Natural language AI"
echo ""

if [ "$UPDATE_SUCCESS" = "true" ]; then
    echo "✅ Gateway enhanced successfully!"
else
    echo "⚠️  Manual enhancement required via AWS console"
    echo "💡 The service role is ready with all necessary permissions"
fi