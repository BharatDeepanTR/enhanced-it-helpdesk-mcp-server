#!/bin/bash
# Example: Gateway with BOTH Lambda targets AND Bedrock model targets

GATEWAY_NAME="a208194-hybrid-gateway"
SERVICE_ROLE_NAME="a208194-hybrid-gateway-role"

# Lambda Targets (Our Current Approach)
CALCULATOR_LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-calculator-mcp-server"
APP_DETAILS_LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-mcp-application-details-server"

# Bedrock Model Targets (Direct Model Access)
CLAUDE_MODEL_ID="anthropic.claude-3-5-sonnet-20241022-v2:0"
LLAMA_MODEL_ID="meta.llama3-2-11b-instruct-v1:0"

cat > hybrid-gateway-request.json << EOF
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
            "targetName": "target-calculator-service",
            "targetDescription": "Custom calculator Lambda with specific business logic",
            "targetConfiguration": {
                "type": "MCP",
                "mcp": {
                    "lambda": {
                        "lambdaArn": "$CALCULATOR_LAMBDA_ARN",
                        "toolSchema": {
                            "inlinePayload": [
                                {
                                    "name": "add",
                                    "description": "Add two numbers with custom business rules",
                                    "inputSchema": {
                                        "type": "object",
                                        "properties": {
                                            "a": {"type": "number"},
                                            "b": {"type": "number"}
                                        },
                                        "required": ["a", "b"]
                                    }
                                }
                            ]
                        }
                    }
                }
            }
        },
        {
            "targetName": "target-application-details-service",
            "targetDescription": "Custom application details lookup from your database",
            "targetConfiguration": {
                "type": "MCP",
                "mcp": {
                    "lambda": {
                        "lambdaArn": "$APP_DETAILS_LAMBDA_ARN",
                        "toolSchema": {
                            "inlinePayload": [
                                {
                                    "name": "get_application_details",
                                    "description": "Get application details from your internal systems",
                                    "inputSchema": {
                                        "type": "object",
                                        "properties": {
                                            "asset_id": {"type": "string"}
                                        },
                                        "required": ["asset_id"]
                                    }
                                }
                            ]
                        }
                    }
                }
            }
        },
        {
            "targetName": "target-bedrock-claude",
            "targetDescription": "Claude model for general AI conversations",
            "targetConfiguration": {
                "type": "BEDROCK_MODEL",
                "bedrockModel": {
                    "modelId": "$CLAUDE_MODEL_ID",
                    "inferenceConfiguration": {
                        "temperature": 0.7,
                        "maxTokens": 1000
                    }
                }
            }
        },
        {
            "targetName": "target-bedrock-llama",
            "targetDescription": "Llama model for specific AI tasks",
            "targetConfiguration": {
                "type": "BEDROCK_MODEL", 
                "bedrockModel": {
                    "modelId": "$LLAMA_MODEL_ID",
                    "inferenceConfiguration": {
                        "temperature": 0.1,
                        "maxTokens": 500
                    }
                }
            }
        }
    ]
}
EOF

echo "Hybrid gateway configuration created!"
echo ""
echo "This gateway would provide:"
echo "  🔧 Custom Tools: Calculator, App Details (via Lambda)"
echo "  🤖 AI Models: Claude, Llama (direct Bedrock)"
echo ""
echo "Clients could:"
echo "  - Ask Claude general questions"
echo "  - Get specific app details from your database"  
echo "  - Perform custom calculations"
echo "  - All through the same gateway endpoint!"