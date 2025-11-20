#!/bin/bash
# CloudShell: Universal MCP Wrapper for ANY Lambda Function
# Makes any Lambda function MCP-compatible without code changes

echo "🌟 Universal MCP Wrapper - One Wrapper for All Lambdas"
echo "====================================================="
echo ""

echo "🎯 Concept: Create ONE wrapper that can adapt ANY Lambda function to MCP protocol"
echo "✅ Benefits: Zero code changes to existing Lambda functions"
echo "🔧 Approach: Configuration-driven wrapper with dynamic tool discovery"
echo ""

WRAPPER_NAME="universal-mcp-wrapper"
REGION="us-east-1"

echo "📋 Universal Wrapper Configuration:"
echo "  Function Name: $WRAPPER_NAME"
echo "  Region: $REGION"
echo ""

echo "🔍 Step 1: Create Universal MCP Wrapper Code"
echo "=========================================="

mkdir -p /tmp/universal-mcp-wrapper
cd /tmp/universal-mcp-wrapper

# Create the universal wrapper code
cat > lambda_function.py << 'EOF'
import json
import boto3
import logging
import os
from typing import Dict, List, Any, Optional

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize clients
lambda_client = boto3.client('lambda')
ssm_client = boto3.client('ssm')

class UniversalMCPWrapper:
    """
    Universal MCP Wrapper that can make ANY Lambda function MCP-compatible
    without requiring code changes to the target Lambda.
    """
    
    def __init__(self):
        self.load_configuration()
    
    def load_configuration(self):
        """
        Load Lambda function mappings from environment variables or SSM Parameter Store
        
        Configuration format:
        {
          "tools": [
            {
              "name": "get_application_details",
              "description": "Get application details for asset ID",
              "lambda_arn": "arn:aws:lambda:us-east-1:123:function:my-function",
              "input_schema": {
                "type": "object",
                "properties": {
                  "asset_id": {"type": "string", "description": "Asset ID"}
                },
                "required": ["asset_id"]
              },
              "input_mapping": {
                "asset_id": "asset_id"
              },
              "output_format": "json"
            }
          ]
        }
        """
        
        # Try to load from environment variable first
        config_json = os.environ.get('MCP_TOOL_CONFIG')
        
        if not config_json:
            # Try to load from SSM Parameter Store
            try:
                parameter_name = os.environ.get('MCP_CONFIG_PARAMETER', '/mcp/universal-wrapper/config')
                response = ssm_client.get_parameter(
                    Name=parameter_name,
                    WithDecryption=True
                )
                config_json = response['Parameter']['Value']
                logger.info(f"Loaded configuration from SSM parameter: {parameter_name}")
            except Exception as e:
                logger.warning(f"Could not load from SSM: {e}")
                # Fall back to default configuration
                config_json = self.get_default_config()
        
        try:
            self.config = json.loads(config_json)
            logger.info(f"Loaded configuration with {len(self.config.get('tools', []))} tools")
        except Exception as e:
            logger.error(f"Failed to parse configuration: {e}")
            self.config = {"tools": []}
    
    def get_default_config(self):
        """Default configuration for your specific use case"""
        return json.dumps({
            "tools": [
                {
                    "name": "get_application_details",
                    "description": "Get application details including name, contact, and regional presence for a given asset ID",
                    "lambda_arn": "arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent",
                    "input_schema": {
                        "type": "object",
                        "properties": {
                            "asset_id": {
                                "type": "string",
                                "description": "The application asset ID (can include 'a' prefix, e.g., 'a12345' or '12345')"
                            }
                        },
                        "required": ["asset_id"]
                    },
                    "input_mapping": {
                        "asset_id": "asset_id"
                    },
                    "output_format": "json"
                }
            ]
        })
    
    def handle_tools_list(self, request_id: str) -> Dict[str, Any]:
        """Handle tools/list MCP request"""
        tools = []
        
        for tool_config in self.config.get('tools', []):
            tool = {
                "name": tool_config['name'],
                "description": tool_config['description'],
                "inputSchema": tool_config['input_schema']
            }
            tools.append(tool)
        
        return {
            "jsonrpc": "2.0",
            "id": request_id,
            "result": {
                "tools": tools
            }
        }
    
    def handle_tools_call(self, request_id: str, params: Dict[str, Any]) -> Dict[str, Any]:
        """Handle tools/call MCP request"""
        tool_name = params.get('name', '')
        tool_arguments = params.get('arguments', {})
        
        # Find the tool configuration
        tool_config = None
        for config in self.config.get('tools', []):
            if config['name'] == tool_name:
                tool_config = config
                break
        
        if not tool_config:
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {
                    "code": -32601,
                    "message": f"Tool not found: {tool_name}"
                }
            }
        
        try:
            # Map input arguments based on configuration
            mapped_input = self.map_input_arguments(tool_arguments, tool_config)
            
            # Invoke the target Lambda function
            lambda_arn = tool_config['lambda_arn']
            
            logger.info(f"Invoking Lambda {lambda_arn} with payload: {mapped_input}")
            
            response = lambda_client.invoke(
                FunctionName=lambda_arn,
                InvocationType='RequestResponse',
                Payload=json.dumps(mapped_input)
            )
            
            # Parse the response
            payload = response['Payload'].read()
            lambda_result = json.loads(payload)
            
            # Check for Lambda errors
            if 'errorMessage' in lambda_result:
                raise Exception(f"Lambda error: {lambda_result['errorMessage']}")
            
            # Format the output
            formatted_output = self.format_output(lambda_result, tool_config)
            
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "content": [
                        {
                            "type": "text",
                            "text": formatted_output
                        }
                    ]
                }
            }
            
        except Exception as e:
            logger.error(f"Error executing tool {tool_name}: {str(e)}")
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {
                    "code": -32603,
                    "message": f"Internal error executing {tool_name}: {str(e)}"
                }
            }
    
    def map_input_arguments(self, arguments: Dict[str, Any], tool_config: Dict[str, Any]) -> Dict[str, Any]:
        """Map MCP tool arguments to Lambda input format"""
        
        input_mapping = tool_config.get('input_mapping', {})
        
        if not input_mapping:
            # No mapping specified, pass arguments as-is
            return arguments
        
        mapped = {}
        for mcp_arg, lambda_arg in input_mapping.items():
            if mcp_arg in arguments:
                mapped[lambda_arg] = arguments[mcp_arg]
        
        # Add any unmapped arguments
        for key, value in arguments.items():
            if key not in input_mapping and key not in mapped:
                mapped[key] = value
        
        return mapped
    
    def format_output(self, lambda_result: Any, tool_config: Dict[str, Any]) -> str:
        """Format Lambda output for MCP response"""
        
        output_format = tool_config.get('output_format', 'json')
        
        if output_format == 'json':
            return json.dumps(lambda_result, indent=2)
        elif output_format == 'text':
            return str(lambda_result)
        else:
            # Custom formatting could be added here
            return json.dumps(lambda_result, indent=2)

# Global wrapper instance
wrapper = UniversalMCPWrapper()

def lambda_handler(event, context):
    """
    Universal MCP Lambda Handler
    
    Supports both API Gateway and direct invocation formats
    """
    
    logger.info(f"Universal MCP Wrapper received event: {json.dumps(event)}")
    
    try:
        # Handle different event formats
        if 'body' in event:
            # API Gateway format
            if isinstance(event['body'], str):
                request_body = json.loads(event['body'])
            else:
                request_body = event['body']
        else:
            # Direct invocation
            request_body = event
        
        # Extract MCP request components
        method = request_body.get('method', '')
        params = request_body.get('params', {})
        request_id = request_body.get('id', 'unknown')
        
        logger.info(f"Processing MCP method: {method}")
        
        # Route to appropriate handler
        if method == 'tools/list':
            response = wrapper.handle_tools_list(request_id)
        elif method == 'tools/call':
            response = wrapper.handle_tools_call(request_id, params)
        else:
            response = {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {
                    "code": -32601,
                    "message": f"Method not found: {method}"
                }
            }
        
        logger.info(f"MCP response: {json.dumps(response)}")
        
        # Return response in appropriate format
        if 'body' in event:
            # API Gateway format
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps(response)
            }
        else:
            # Direct invocation
            return response
            
    except Exception as e:
        logger.error(f"Universal MCP Wrapper error: {str(e)}")
        
        error_response = {
            "jsonrpc": "2.0",
            "id": request_body.get('id', 'unknown') if 'request_body' in locals() else 'unknown',
            "error": {
                "code": -32603,
                "message": f"Internal error: {str(e)}"
            }
        }
        
        if 'body' in event:
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps(error_response)
            }
        else:
            return error_response
EOF

echo "✅ Universal wrapper code created!"

echo ""
echo "🔍 Step 2: Create Configuration Examples"
echo "======================================="

# Example configuration for multiple Lambda functions
cat > config-examples.json << 'EOF'
{
  "description": "Universal MCP Wrapper Configuration Examples",
  "examples": [
    {
      "name": "Single Lambda Configuration",
      "config": {
        "tools": [
          {
            "name": "get_application_details",
            "description": "Get application details for asset ID",
            "lambda_arn": "arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent",
            "input_schema": {
              "type": "object",
              "properties": {
                "asset_id": {"type": "string", "description": "Asset ID"}
              },
              "required": ["asset_id"]
            },
            "input_mapping": {
              "asset_id": "asset_id"
            },
            "output_format": "json"
          }
        ]
      }
    },
    {
      "name": "Multiple Lambda Functions",
      "config": {
        "tools": [
          {
            "name": "get_application_details",
            "description": "Get application details for asset ID",
            "lambda_arn": "arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent",
            "input_schema": {
              "type": "object",
              "properties": {
                "asset_id": {"type": "string", "description": "Asset ID"}
              },
              "required": ["asset_id"]
            }
          },
          {
            "name": "get_user_profile",
            "description": "Get user profile information",
            "lambda_arn": "arn:aws:lambda:us-east-1:818565325759:function:user-profile-function",
            "input_schema": {
              "type": "object",
              "properties": {
                "user_id": {"type": "string", "description": "User ID"},
                "include_permissions": {"type": "boolean", "description": "Include user permissions"}
              },
              "required": ["user_id"]
            },
            "input_mapping": {
              "user_id": "userId",
              "include_permissions": "includePerms"
            }
          },
          {
            "name": "send_notification",
            "description": "Send notification to user",
            "lambda_arn": "arn:aws:lambda:us-east-1:818565325759:function:notification-service",
            "input_schema": {
              "type": "object",
              "properties": {
                "recipient": {"type": "string", "description": "Recipient email"},
                "message": {"type": "string", "description": "Message content"},
                "priority": {"type": "string", "enum": ["low", "medium", "high"]}
              },
              "required": ["recipient", "message"]
            },
            "output_format": "text"
          }
        ]
      }
    },
    {
      "name": "Complex Input Mapping Example",
      "config": {
        "tools": [
          {
            "name": "process_order",
            "description": "Process customer order",
            "lambda_arn": "arn:aws:lambda:us-east-1:818565325759:function:order-processor",
            "input_schema": {
              "type": "object",
              "properties": {
                "customer_id": {"type": "string", "description": "Customer ID"},
                "product_ids": {"type": "array", "items": {"type": "string"}},
                "shipping_address": {
                  "type": "object",
                  "properties": {
                    "street": {"type": "string"},
                    "city": {"type": "string"},
                    "zip": {"type": "string"}
                  }
                },
                "express_shipping": {"type": "boolean"}
              },
              "required": ["customer_id", "product_ids"]
            },
            "input_mapping": {
              "customer_id": "customerId",
              "product_ids": "products",
              "shipping_address": "address",
              "express_shipping": "isExpress"
            }
          }
        ]
      }
    }
  ]
}
EOF

echo "✅ Configuration examples created!"

echo ""
echo "🔍 Step 3: Create Deployment Scripts"
echo "==================================="

# Script to deploy universal wrapper
cat > deploy-universal-wrapper.sh << 'DEPLOY_EOF'
#!/bin/bash
# Deploy Universal MCP Wrapper

WRAPPER_NAME="universal-mcp-wrapper"
ROLE_ARN="arn:aws:iam::818565325759:role/a208194-askjulius-agentcore-gateway"

echo "🚀 Deploying Universal MCP Wrapper..."

# Create deployment package
zip -r universal-mcp-wrapper.zip lambda_function.py

# Deploy Lambda function
aws lambda create-function \
  --function-name "$WRAPPER_NAME" \
  --runtime python3.9 \
  --role "$ROLE_ARN" \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://universal-mcp-wrapper.zip \
  --description "Universal MCP wrapper - makes any Lambda MCP-compatible" \
  --timeout 60 \
  --memory-size 256 \
  --environment Variables='{
    "MCP_CONFIG_PARAMETER":"/mcp/universal-wrapper/config"
  }' \
  --output json

echo "✅ Universal wrapper deployed!"

# Get the function ARN
WRAPPER_ARN=$(aws lambda get-function --function-name "$WRAPPER_NAME" --query 'Configuration.FunctionArn' --output text)
echo "📋 Wrapper ARN: $WRAPPER_ARN"
DEPLOY_EOF

chmod +x deploy-universal-wrapper.sh

# Script to configure tools
cat > configure-tools.sh << 'CONFIG_EOF'
#!/bin/bash
# Configure tools for Universal MCP Wrapper

echo "🔧 Configuring tools for Universal MCP Wrapper..."

# Default configuration for your current use case
CONFIG_JSON='{
  "tools": [
    {
      "name": "get_application_details",
      "description": "Get application details including name, contact, and regional presence for a given asset ID",
      "lambda_arn": "arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent",
      "input_schema": {
        "type": "object",
        "properties": {
          "asset_id": {
            "type": "string",
            "description": "The application asset ID (can include a prefix, e.g., a12345 or 12345)"
          }
        },
        "required": ["asset_id"]
      },
      "input_mapping": {
        "asset_id": "asset_id"
      },
      "output_format": "json"
    }
  ]
}'

# Store configuration in SSM Parameter Store
aws ssm put-parameter \
  --name "/mcp/universal-wrapper/config" \
  --value "$CONFIG_JSON" \
  --type "String" \
  --description "Universal MCP Wrapper tool configuration" \
  --overwrite

echo "✅ Configuration stored in SSM Parameter Store!"

# Update Lambda environment to use the configuration
aws lambda update-function-configuration \
  --function-name "universal-mcp-wrapper" \
  --environment Variables='{
    "MCP_CONFIG_PARAMETER":"/mcp/universal-wrapper/config"
  }'

echo "✅ Lambda environment updated!"
CONFIG_EOF

chmod +x configure-tools.sh

# Script to add more tools
cat > add-tool.sh << 'ADD_TOOL_EOF'
#!/bin/bash
# Add new tool to Universal MCP Wrapper

if [ $# -lt 5 ]; then
    echo "Usage: $0 <tool_name> <description> <lambda_arn> <input_schema_json> <input_mapping_json>"
    echo ""
    echo "Example:"
    echo "$0 'get_user_info' 'Get user information' 'arn:aws:lambda:...:function:user-service' '{\"type\":\"object\",\"properties\":{\"user_id\":{\"type\":\"string\"}}}' '{\"user_id\":\"userId\"}'"
    exit 1
fi

TOOL_NAME="$1"
DESCRIPTION="$2"
LAMBDA_ARN="$3"
INPUT_SCHEMA="$4"
INPUT_MAPPING="$5"

echo "➕ Adding new tool: $TOOL_NAME"

# Get current configuration
CURRENT_CONFIG=$(aws ssm get-parameter --name "/mcp/universal-wrapper/config" --query 'Parameter.Value' --output text)

# Add new tool (this is a simplified version - you'd want proper JSON manipulation)
echo "Current config: $CURRENT_CONFIG"
echo ""
echo "New tool to add:"
echo "  Name: $TOOL_NAME"
echo "  Description: $DESCRIPTION"
echo "  Lambda ARN: $LAMBDA_ARN"
echo "  Input Schema: $INPUT_SCHEMA"
echo "  Input Mapping: $INPUT_MAPPING"

echo ""
echo "⚠️  Please manually update the SSM parameter or use the configuration examples"
ADD_TOOL_EOF

chmod +x add-tool.sh

echo "✅ Deployment scripts created!"

cd - > /dev/null

echo ""
echo "🧪 Step 4: Create Testing Script"
echo "==============================="

cat > test-universal-wrapper.sh << 'TEST_EOF'
#!/bin/bash
# Test Universal MCP Wrapper

WRAPPER_NAME="universal-mcp-wrapper"

echo "🧪 Testing Universal MCP Wrapper..."

# Test 1: tools/list
echo ""
echo "Test 1: tools/list"
echo "=================="

aws lambda invoke \
  --function-name "$WRAPPER_NAME" \
  --payload '{"jsonrpc":"2.0","id":"test-1","method":"tools/list","params":{}}' \
  /tmp/tools-list-response.json

echo "Response:"
cat /tmp/tools-list-response.json | jq . 2>/dev/null || cat /tmp/tools-list-response.json

# Test 2: tools/call
echo ""
echo ""
echo "Test 2: tools/call"
echo "=================="

aws lambda invoke \
  --function-name "$WRAPPER_NAME" \
  --payload '{"jsonrpc":"2.0","id":"test-2","method":"tools/call","params":{"name":"get_application_details","arguments":{"asset_id":"a208194"}}}' \
  /tmp/tools-call-response.json

echo "Response:"
cat /tmp/tools-call-response.json | jq . 2>/dev/null || cat /tmp/tools-call-response.json

# Test 3: Error handling
echo ""
echo ""
echo "Test 3: Error handling (unknown tool)"
echo "====================================="

aws lambda invoke \
  --function-name "$WRAPPER_NAME" \
  --payload '{"jsonrpc":"2.0","id":"test-3","method":"tools/call","params":{"name":"nonexistent_tool","arguments":{}}}' \
  /tmp/error-test-response.json

echo "Response:"
cat /tmp/error-test-response.json | jq . 2>/dev/null || cat /tmp/error-test-response.json

# Clean up
rm -f /tmp/tools-list-response.json /tmp/tools-call-response.json /tmp/error-test-response.json

echo ""
echo "✅ Testing completed!"
TEST_EOF

chmod +x test-universal-wrapper.sh

echo ""
echo "📋 UNIVERSAL MCP WRAPPER SUMMARY"
echo "================================"

echo ""
echo "🎯 What you've got:"
echo "   ✅ Universal wrapper that works with ANY Lambda function"
echo "   ✅ Configuration-driven (no code changes needed)"
echo "   ✅ Support for multiple tools in one wrapper"
echo "   ✅ Input/output mapping capabilities"
echo "   ✅ Easy deployment and management scripts"

echo ""
echo "📁 Files created:"
echo "   📄 lambda_function.py - Universal wrapper code"
echo "   📄 config-examples.json - Configuration examples"
echo "   📄 deploy-universal-wrapper.sh - Deployment script"
echo "   📄 configure-tools.sh - Tool configuration script"
echo "   📄 add-tool.sh - Script to add new tools"
echo "   📄 test-universal-wrapper.sh - Testing script"

echo ""
echo "🚀 Quick Start:"
echo "   1. cd /tmp/universal-mcp-wrapper"
echo "   2. ./deploy-universal-wrapper.sh"
echo "   3. ./configure-tools.sh"
echo "   4. ./test-universal-wrapper.sh"

echo ""
echo "🔧 To add more Lambda functions:"
echo "   1. Update SSM parameter: /mcp/universal-wrapper/config"
echo "   2. Add new tool configuration to the JSON"
echo "   3. No code changes needed!"

echo ""
echo "🎉 Benefits:"
echo "   ✅ ONE wrapper for ALL your Lambda functions"
echo "   ✅ ZERO code changes to existing Lambdas"
echo "   ✅ Easy to add/remove/modify tools"
echo "   ✅ Centralized configuration management"
echo "   ✅ Consistent MCP protocol implementation"

echo ""
echo "✅ Universal MCP Wrapper creation completed!"
echo "🌟 Now ANY Lambda can be MCP-compatible!"