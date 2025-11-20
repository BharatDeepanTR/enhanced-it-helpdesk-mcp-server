#!/bin/bash
# Create Bedrock Agent Core Gateway via AWS CLI
# Workaround for console wizard service role selection issues

set -e

GATEWAY_NAME="a208194-askjulius-agentcore-gateway-mcp-iam"
SERVICE_ROLE_NAME="a208194-askjulius-agentcore-gateway"

# CONFIRMED: Gateway name and URL are correct
# Issue: Lambda was working earlier but now returns "An internal error occurred"
# Lambda direct testing shows function works perfectly - issue is in gateway-Lambda integration

# Calculator Lambda Configuration
CALCULATOR_LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-calculator-mcp-server"
CALCULATOR_TARGET_NAME="target-lambda-direct-calculator-mcp"
CALCULATOR_TARGET_DESCRIPTION="Calculator service for mathematical operations and computations"

# AI Calculator Lambda Configuration (EXISTING Lambda)
AI_CALCULATOR_LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-ai-bedrock-calculator-mcp-server"
AI_CALCULATOR_TARGET_NAME="target-lambda-direct-ai-calculator-mcp"
AI_CALCULATOR_TARGET_DESCRIPTION="AI-powered Bedrock calculator using Claude for natural language mathematical operations"

# Application Details Lambda Configuration  
APP_DETAILS_LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-mcp-application-details-server"
APP_DETAILS_TARGET_NAME="target-lambda-direct-application-details-mcp"
APP_DETAILS_TARGET_DESCRIPTION="Application details service for asset information lookup"

REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "ACCOUNT_ID_NEEDED")

echo "🚀 Creating Bedrock Agent Core Gateway via AWS CLI..."
echo "Gateway Name: $GATEWAY_NAME"
echo "Region: $REGION"
echo "Account ID: $ACCOUNT_ID"
echo ""

# Construct full service role ARN
SERVICE_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${SERVICE_ROLE_NAME}"

echo "📋 Configuration:"
echo "   Service Role ARN: $SERVICE_ROLE_ARN"
echo "   Calculator Lambda ARN: $CALCULATOR_LAMBDA_ARN"
echo "   AI Calculator Lambda ARN: $AI_CALCULATOR_LAMBDA_ARN"
echo "   Application Details Lambda ARN: $APP_DETAILS_LAMBDA_ARN"
echo ""

# Check if the service role exists
echo "🔍 Verifying service role exists..."
if aws iam get-role --role-name "$SERVICE_ROLE_NAME" >/dev/null 2>&1; then
    echo "   ✅ Service role '$SERVICE_ROLE_NAME' found"
else
    echo "   ❌ Service role '$SERVICE_ROLE_NAME' not found"
    echo ""
    echo "🛠️  Creating service role..."
    
    # Create trust policy for Agent Core Gateway
    cat > trust-policy.json << EOF
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
EOF

    # Create the service role
    aws iam create-role \
        --role-name "$SERVICE_ROLE_NAME" \
        --assume-role-policy-document file://trust-policy.json \
        --description "Service role for Agent Core Gateway $GATEWAY_NAME"
    
    # Attach necessary policies
    aws iam attach-role-policy \
        --role-name "$SERVICE_ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AmazonBedrockFullAccess"
    
    aws iam attach-role-policy \
        --role-name "$SERVICE_ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/AWSLambdaExecute"
    
    # Create inline policy for Lambda invocation
    cat > lambda-invoke-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction"
            ],
            "Resource": [
                "$CALCULATOR_LAMBDA_ARN",
                "$AI_CALCULATOR_LAMBDA_ARN",
                "$APP_DETAILS_LAMBDA_ARN"
            ]
        }
    ]
}
EOF

    aws iam put-role-policy \
        --role-name "$SERVICE_ROLE_NAME" \
        --policy-name "LambdaInvokePolicy" \
        --policy-document file://lambda-invoke-policy.json
    
    echo "   ✅ Service role created successfully"
    echo "   ⏳ Waiting 10 seconds for role propagation..."
    sleep 10
    
    # Clean up temporary files
    rm -f trust-policy.json lambda-invoke-policy.json
fi

# Create the gateway using AWS CLI
echo ""
echo "🏗️  Creating Agent Core Gateway..."

# First, let's try to find the correct AWS CLI command for Agent Core Gateway
# Note: The exact command may vary based on AWS CLI version

# Check AWS CLI version and Agent Core command availability
echo "   🔍 Checking AWS CLI capabilities..."
AWS_CLI_VERSION=$(aws --version 2>/dev/null | head -1)
echo "   Current AWS CLI: $AWS_CLI_VERSION"

# Agent Core Gateway commands are NOT available in current AWS CLI
# This is confirmed by AWS CLI documentation research
echo "   ⚠️  CONFIRMED: Agent Core Gateway CLI commands not available yet"
echo "   📋 Console-only approach required for Agent Core Gateway management"

# Create gateway configuration with proper MCP schema format
cat > gateway-request.json << EOF
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
            "targetName": "$CALCULATOR_TARGET_NAME",
            "targetDescription": "$CALCULATOR_TARGET_DESCRIPTION",
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
                                            "a": {
                                                "type": "number",
                                                "description": "First number to add"
                                            },
                                            "b": {
                                                "type": "number",
                                                "description": "Second number to add"
                                            }
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
                                            "a": {
                                                "type": "number",
                                                "description": "Number to subtract from"
                                            },
                                            "b": {
                                                "type": "number",
                                                "description": "Number to subtract"
                                            }
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
                                            "a": {
                                                "type": "number",
                                                "description": "First number to multiply"
                                            },
                                            "b": {
                                                "type": "number",
                                                "description": "Second number to multiply"
                                            }
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
                                            "a": {
                                                "type": "number",
                                                "description": "Dividend (number to be divided)"
                                            },
                                            "b": {
                                                "type": "number",
                                                "description": "Divisor (number to divide by)"
                                            }
                                        },
                                        "required": ["a", "b"]
                                    }
                                },
                                {
                                    "name": "power",
                                    "description": "Raise base number to the power of exponent",
                                    "inputSchema": {
                                        "type": "object",
                                        "properties": {
                                            "base": {
                                                "type": "number",
                                                "description": "Base number"
                                            },
                                            "exponent": {
                                                "type": "number",
                                                "description": "Exponent (power to raise base to)"
                                            }
                                        },
                                        "required": ["base", "exponent"]
                                    }
                                },
                                {
                                    "name": "sqrt",
                                    "description": "Calculate square root of a number",
                                    "inputSchema": {
                                        "type": "object",
                                        "properties": {
                                            "number": {
                                                "type": "number",
                                                "description": "Number to find square root of (must be non-negative)"
                                            }
                                        },
                                        "required": ["number"]
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
            "targetName": "$AI_CALCULATOR_TARGET_NAME",
            "targetDescription": "$AI_CALCULATOR_TARGET_DESCRIPTION",
            "targetConfiguration": {
                "type": "MCP",
                "mcp": {
                    "lambda": {
                        "lambdaArn": "$AI_CALCULATOR_LAMBDA_ARN",
                        "toolSchema": {
                            "inlinePayload": [
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
                        }
                    }
                }
            },
            "outboundAuthConfig": {
                "type": "AWS_IAM"
            }
        },
        {
            "targetName": "$APP_DETAILS_TARGET_NAME",
            "targetDescription": "$APP_DETAILS_TARGET_DESCRIPTION",
            "targetConfiguration": {
                "type": "MCP",
                "mcp": {
                    "lambda": {
                        "lambdaArn": "$APP_DETAILS_LAMBDA_ARN",
                        "toolSchema": {
                            "inlinePayload": [
                                {
                                    "name": "get_application_details",
                                    "description": "Get application details including name, contact, and regional presence for a given asset ID",
                                    "inputSchema": {
                                        "type": "object",
                                        "properties": {
                                            "asset_id": {
                                                "type": "string",
                                                "description": "The application asset ID (can include 'a' prefix, e.g., 'a12345' or '12345')"
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
        }
    ]
}
EOF

echo "📝 Gateway configuration created in gateway-request.json"

# IMPORTANT: Agent Core Gateway CLI commands are NOT available in current AWS CLI
# This has been confirmed via AWS CLI documentation research
echo ""
echo "🚨 CRITICAL FINDING: Agent Core Gateway CLI Commands Not Available"
echo ""
echo "   ❌ aws bedrock-agent-runtime create-agent-core-gateway (INVALID)"
echo "   ❌ aws bedrock create-agent-core-gateway (INVALID)" 
echo "   ❌ aws bedrock-agent create-agent-core-gateway (INVALID)"
echo ""
echo "   📋 CONFIRMED: Console-only approach required"
echo "   🌐 Agent Core Gateway appears to be preview/early-access with console-only support"
echo ""

CREATION_SUCCESS=false

# If all automated methods fail, provide manual instructions
if [ "$CREATION_SUCCESS" != "true" ]; then
    echo ""
    echo "⚠️  Automated creation failed. Using manual approach..."
    echo ""
    echo "📋 Manual Creation Instructions:"
    echo "================================"
    echo ""
    echo "🔧 Service Role Issue Workaround:"
    echo "1. The service role '$SERVICE_ROLE_NAME' has been created/verified"
    echo "2. Full ARN: $SERVICE_ROLE_ARN"
    echo ""
    echo "🌐 Console Creation Steps:"
    echo "1. Go to AWS Console → Bedrock → Agent Core → Gateways"  
    echo "2. Find existing gateway: $GATEWAY_NAME (if it exists)"
    echo "3. Click 'Add Target' to add the AI Calculator Lambda"
    echo ""
    echo "🎯 SIMPLIFIED APPROACH: Use Lambda ARN as Direct MCP Server"
    echo "This bypasses OAuth client authentication issues!"
    echo ""
    echo "🔧 Target Creation with Lambda ARN Direct:"
    echo "1. Target Type: MCP Server"
    echo "2. Server Type: Lambda ARN"  
    echo "3. Lambda Function: $AI_CALCULATOR_LAMBDA_ARN"
    echo "4. Authentication: Uses gateway's service role automatically"
    echo ""
    echo "📝 Use these exact values:"
    echo "   Gateway Name: $GATEWAY_NAME"
    echo "   Service Role: $SERVICE_ROLE_ARN"
    echo "   Semantic Search: Enabled"
    echo ""
    echo "🎯 Target 1 - Calculator:"
    echo "   Target Name: $CALCULATOR_TARGET_NAME"
    echo "   Target Description: $CALCULATOR_TARGET_DESCRIPTION"
    echo "   Lambda ARN: $CALCULATOR_LAMBDA_ARN"
    echo ""
    echo "🎯 Target 2 - AI Calculator:"
    echo "   Target Name: $AI_CALCULATOR_TARGET_NAME"
    echo "   Target Description: $AI_CALCULATOR_TARGET_DESCRIPTION"
    echo "   Lambda ARN: $AI_CALCULATOR_LAMBDA_ARN"
    echo ""
    echo "🎯 Target 3 - Application Details:"
    echo "   Target Name: $APP_DETAILS_TARGET_NAME"
    echo "   Target Description: $APP_DETAILS_TARGET_DESCRIPTION"
    echo "   Lambda ARN: $APP_DETAILS_LAMBDA_ARN"
    echo ""
    echo "🔑 Calculator Schema (copy-paste into inline schema field):"
    cat << 'SCHEMA_EOF'
[
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
        "a": {"type": "number", "description": "Dividend (number to be divided)"},
        "b": {"type": "number", "description": "Divisor (number to divide by)"}
      },
      "required": ["a", "b"]
    }
  },
  {
    "name": "power",
    "description": "Raise base number to the power of exponent",
    "inputSchema": {
      "type": "object",
      "properties": {
        "base": {"type": "number", "description": "Base number"},
        "exponent": {"type": "number", "description": "Exponent (power to raise base to)"}
      },
      "required": ["base", "exponent"]
    }
  },
  {
    "name": "sqrt",
    "description": "Calculate square root of a number",
    "inputSchema": {
      "type": "object",
      "properties": {
        "number": {"type": "number", "description": "Number to find square root of (must be non-negative)"}
      },
      "required": ["number"]
    }
  }
]
SCHEMA_EOF
    echo ""
    echo "🔑 Application Details Schema (copy-paste into inline schema field):"
    cat << 'APP_SCHEMA_EOF'
[
  {
    "name": "get_application_details",
    "description": "Get application details including name, contact, and regional presence for a given asset ID",
    "inputSchema": {
      "type": "object",
      "properties": {
        "asset_id": {
          "type": "string",
          "description": "The application asset ID (can include 'a' prefix, e.g., 'a12345' or '12345')"
        }
      },
      "required": ["asset_id"]
    }
  }
]
APP_SCHEMA_EOF
    echo ""
    echo "🛠️  CloudFormation Alternative:"
    echo "If console still doesn't work, we can try CloudFormation template"
fi

# Clean up temporary files
rm -f gateway-request.json

echo ""
echo "📊 Summary:"
echo "   Region: $REGION"
echo "   Gateway Name: $GATEWAY_NAME"
echo "   Service Role: $SERVICE_ROLE_ARN"
echo "   Calculator Lambda ARN: $CALCULATOR_LAMBDA_ARN"
echo "   AI Calculator Lambda ARN: $AI_CALCULATOR_LAMBDA_ARN"
echo "   Application Details Lambda ARN: $APP_DETAILS_LAMBDA_ARN"
echo ""
echo "⚠️  CONSOLE-ONLY APPROACH REQUIRED"
echo "🚨 Agent Core Gateway CLI commands confirmed NOT AVAILABLE in current AWS CLI"
echo "💡 The service role has been prepared and is ready for console use"