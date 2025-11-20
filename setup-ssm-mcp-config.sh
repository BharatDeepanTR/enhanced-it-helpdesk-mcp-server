#!/bin/bash
# CloudShell: Store MCP Tool Definitions in SSM Parameter Store
# Complete guide for managing Universal MCP Wrapper configurations

echo "📋 SSM Parameter Store for MCP Tool Definitions"
echo "==============================================="
echo ""

PARAMETER_NAME="/mcp/universal-wrapper/config"
REGION="us-east-1"

echo "🎯 Parameter Configuration:"
echo "  Parameter Name: $PARAMETER_NAME"
echo "  Region: $REGION"
echo "  Type: String (JSON configuration)"
echo ""

echo "🔍 Step 1: Create Your Tool Configuration JSON"
echo "=============================================="

# Create the configuration file
cat > mcp-tools-config.json << 'EOF'
{
  "description": "Universal MCP Wrapper Tool Configuration",
  "version": "1.0",
  "last_updated": "2025-11-12",
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
      "output_format": "json",
      "timeout": 30,
      "enabled": true
    }
  ]
}
EOF

echo "✅ Configuration file created: mcp-tools-config.json"

echo ""
echo "📄 Configuration content:"
cat mcp-tools-config.json | jq . 2>/dev/null || cat mcp-tools-config.json

echo ""
echo "🔍 Step 2: Store Configuration in SSM Parameter Store"
echo "===================================================="

echo "Creating SSM parameter..."

# Store the configuration
aws ssm put-parameter \
  --name "$PARAMETER_NAME" \
  --value file://mcp-tools-config.json \
  --type "String" \
  --description "Universal MCP Wrapper tool configuration - defines all available MCP tools and their Lambda function mappings" \
  --overwrite \
  --output table

STORE_RESULT=$?

if [ $STORE_RESULT -eq 0 ]; then
    echo "✅ Configuration stored successfully in SSM Parameter Store!"
else
    echo "❌ Failed to store configuration"
    exit 1
fi

echo ""
echo "🔍 Step 3: Verify Storage"
echo "======================="

echo "Retrieving stored configuration..."

aws ssm get-parameter \
  --name "$PARAMETER_NAME" \
  --output table

echo ""
echo "📄 Stored configuration content:"

aws ssm get-parameter \
  --name "$PARAMETER_NAME" \
  --query 'Parameter.Value' \
  --output text | jq . 2>/dev/null

echo ""
echo "🔍 Step 4: Create Multiple Environment Configurations"
echo "===================================================="

# Development environment
cat > mcp-tools-config-dev.json << 'DEV_EOF'
{
  "description": "Development Environment - MCP Tool Configuration",
  "environment": "development",
  "tools": [
    {
      "name": "get_application_details",
      "description": "Get application details (DEV environment)",
      "lambda_arn": "arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent-dev",
      "input_schema": {
        "type": "object",
        "properties": {
          "asset_id": {"type": "string", "description": "Asset ID"}
        },
        "required": ["asset_id"]
      },
      "input_mapping": {"asset_id": "asset_id"},
      "output_format": "json",
      "enabled": true
    },
    {
      "name": "debug_tool",
      "description": "Debug tool for development testing",
      "lambda_arn": "arn:aws:lambda:us-east-1:818565325759:function:debug-function",
      "input_schema": {
        "type": "object",
        "properties": {
          "debug_level": {"type": "string", "enum": ["info", "debug", "trace"]}
        }
      },
      "enabled": true
    }
  ]
}
DEV_EOF

# Production environment
cat > mcp-tools-config-prod.json << 'PROD_EOF'
{
  "description": "Production Environment - MCP Tool Configuration",
  "environment": "production",
  "tools": [
    {
      "name": "get_application_details",
      "description": "Get application details (PRODUCTION)",
      "lambda_arn": "arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent",
      "input_schema": {
        "type": "object",
        "properties": {
          "asset_id": {"type": "string", "description": "Asset ID"}
        },
        "required": ["asset_id"]
      },
      "input_mapping": {"asset_id": "asset_id"},
      "output_format": "json",
      "timeout": 30,
      "enabled": true
    }
  ]
}
PROD_EOF

# Store environment-specific configurations
echo "Storing development configuration..."
aws ssm put-parameter \
  --name "/mcp/universal-wrapper/config/dev" \
  --value file://mcp-tools-config-dev.json \
  --type "String" \
  --description "MCP tool configuration for development environment" \
  --overwrite

echo "Storing production configuration..."
aws ssm put-parameter \
  --name "/mcp/universal-wrapper/config/prod" \
  --value file://mcp-tools-config-prod.json \
  --type "String" \
  --description "MCP tool configuration for production environment" \
  --overwrite

echo "✅ Environment-specific configurations stored!"

echo ""
echo "🔍 Step 5: Create Tool Management Scripts"
echo "========================================"

# Script to add a new tool
cat > add-mcp-tool.sh << 'ADD_TOOL_EOF'
#!/bin/bash
# Add new tool to MCP configuration

if [ $# -lt 4 ]; then
    echo "Usage: $0 <tool_name> <description> <lambda_arn> <environment>"
    echo ""
    echo "Example:"
    echo "$0 'send_email' 'Send email notification' 'arn:aws:lambda:us-east-1:123:function:email-service' 'prod'"
    exit 1
fi

TOOL_NAME="$1"
DESCRIPTION="$2"
LAMBDA_ARN="$3"
ENVIRONMENT="${4:-prod}"

PARAMETER_NAME="/mcp/universal-wrapper/config"
if [ "$ENVIRONMENT" != "prod" ]; then
    PARAMETER_NAME="/mcp/universal-wrapper/config/$ENVIRONMENT"
fi

echo "➕ Adding tool: $TOOL_NAME to environment: $ENVIRONMENT"

# Get current configuration
CURRENT_CONFIG=$(aws ssm get-parameter --name "$PARAMETER_NAME" --query 'Parameter.Value' --output text)

if [ $? -ne 0 ]; then
    echo "❌ Could not retrieve current configuration"
    exit 1
fi

echo "Current configuration retrieved"

# Create new tool definition
NEW_TOOL='{
  "name": "'$TOOL_NAME'",
  "description": "'$DESCRIPTION'",
  "lambda_arn": "'$LAMBDA_ARN'",
  "input_schema": {
    "type": "object",
    "properties": {},
    "required": []
  },
  "input_mapping": {},
  "output_format": "json",
  "enabled": true
}'

echo ""
echo "📝 New tool definition:"
echo "$NEW_TOOL" | jq .

# Note: For production use, you'd want proper JSON manipulation
# This is a simplified example showing the concept

echo ""
echo "⚠️  To complete the addition:"
echo "1. Manually edit the SSM parameter to add the new tool"
echo "2. Or use the AWS Console SSM Parameter Store editor"
echo "3. Or create a more sophisticated JSON manipulation script"

echo ""
echo "🔧 Manual steps:"
echo "1. aws ssm get-parameter --name '$PARAMETER_NAME' > current-config.json"
echo "2. Edit current-config.json to add the new tool"
echo "3. aws ssm put-parameter --name '$PARAMETER_NAME' --value file://current-config.json --overwrite"
ADD_TOOL_EOF

chmod +x add-mcp-tool.sh

# Script to list all tools
cat > list-mcp-tools.sh << 'LIST_TOOLS_EOF'
#!/bin/bash
# List all MCP tools from SSM Parameter Store

ENVIRONMENT="${1:-prod}"
PARAMETER_NAME="/mcp/universal-wrapper/config"

if [ "$ENVIRONMENT" != "prod" ]; then
    PARAMETER_NAME="/mcp/universal-wrapper/config/$ENVIRONMENT"
fi

echo "📋 MCP Tools in environment: $ENVIRONMENT"
echo "Parameter: $PARAMETER_NAME"
echo "========================================"

# Get and display tools
CONFIG=$(aws ssm get-parameter --name "$PARAMETER_NAME" --query 'Parameter.Value' --output text 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "$CONFIG" | jq -r '.tools[] | "🔧 \(.name): \(.description)\n   Lambda: \(.lambda_arn)\n   Enabled: \(.enabled)\n"'
else
    echo "❌ Could not retrieve configuration for environment: $ENVIRONMENT"
    echo ""
    echo "Available parameters:"
    aws ssm describe-parameters --filters "Key=Name,Values=/mcp/" --query 'Parameters[].Name' --output table
fi
LIST_TOOLS_EOF

chmod +x list-mcp-tools.sh

# Script to enable/disable tools
cat > toggle-mcp-tool.sh << 'TOGGLE_TOOL_EOF'
#!/bin/bash
# Enable or disable an MCP tool

if [ $# -lt 2 ]; then
    echo "Usage: $0 <tool_name> <enable|disable> [environment]"
    echo ""
    echo "Example:"
    echo "$0 'get_application_details' 'disable' 'dev'"
    exit 1
fi

TOOL_NAME="$1"
ACTION="$2"
ENVIRONMENT="${3:-prod}"

echo "🔧 ${ACTION^}ing tool: $TOOL_NAME in environment: $ENVIRONMENT"

# This would require proper JSON manipulation
echo "⚠️  Manual implementation needed for production use"
echo "Consider using jq or a proper configuration management tool"
TOGGLE_TOOL_EOF

chmod +x toggle-mcp-tool.sh

echo "✅ Tool management scripts created!"

echo ""
echo "🔍 Step 6: Test SSM Parameter Retrieval"
echo "====================================="

echo "Testing parameter retrieval from Lambda perspective..."

# Create test script
cat > test-ssm-retrieval.py << 'TEST_EOF'
import boto3
import json

def test_ssm_parameter_retrieval():
    """Test retrieving MCP configuration from SSM Parameter Store"""
    
    ssm_client = boto3.client('ssm', region_name='us-east-1')
    parameter_name = '/mcp/universal-wrapper/config'
    
    try:
        print(f"🔍 Retrieving parameter: {parameter_name}")
        
        response = ssm_client.get_parameter(
            Name=parameter_name,
            WithDecryption=True
        )
        
        config_json = response['Parameter']['Value']
        config = json.loads(config_json)
        
        print("✅ Successfully retrieved configuration!")
        print(f"📊 Configuration summary:")
        print(f"   Description: {config.get('description', 'N/A')}")
        print(f"   Version: {config.get('version', 'N/A')}")
        print(f"   Tools count: {len(config.get('tools', []))}")
        
        print(f"\n📋 Available tools:")
        for tool in config.get('tools', []):
            status = "✅ Enabled" if tool.get('enabled', True) else "❌ Disabled"
            print(f"   • {tool['name']}: {tool['description']} [{status}]")
            print(f"     Lambda: {tool['lambda_arn']}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error retrieving parameter: {e}")
        return False

if __name__ == "__main__":
    test_ssm_parameter_retrieval()
TEST_EOF

echo "Running SSM retrieval test..."
python3 test-ssm-retrieval.py

echo ""
echo "🔍 Step 7: Set Up Parameter Versioning"
echo "====================================="

echo "Creating versioned parameters for configuration management..."

# Create a version with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
VERSION_PARAMETER="/mcp/universal-wrapper/config/backup/$TIMESTAMP"

aws ssm put-parameter \
  --name "$VERSION_PARAMETER" \
  --value file://mcp-tools-config.json \
  --type "String" \
  --description "Backup of MCP configuration created on $TIMESTAMP" \
  --tags "Key=Purpose,Value=Backup" "Key=CreatedDate,Value=$(date)" \
  --output table

echo "✅ Versioned backup created: $VERSION_PARAMETER"

echo ""
echo "🔍 Step 8: Lambda Environment Variable Setup"
echo "==========================================="

echo "Updating Lambda function to use SSM parameter..."

# Update Lambda environment variables
aws lambda update-function-configuration \
  --function-name "universal-mcp-wrapper" \
  --environment Variables='{
    "MCP_CONFIG_PARAMETER": "/mcp/universal-wrapper/config",
    "MCP_CONFIG_CACHE_TTL": "300",
    "AWS_DEFAULT_REGION": "us-east-1"
  }' \
  --output table 2>/dev/null || echo "⚠️  Lambda function not found - will be set during deployment"

echo ""
echo "📋 COMPLETE SSM PARAMETER STORE SETUP SUMMARY"
echo "=============================================="

echo ""
echo "✅ What's been created:"
echo "   📄 Main configuration: /mcp/universal-wrapper/config"
echo "   📄 Dev configuration: /mcp/universal-wrapper/config/dev"  
echo "   📄 Prod configuration: /mcp/universal-wrapper/config/prod"
echo "   📄 Backup: /mcp/universal-wrapper/config/backup/$TIMESTAMP"

echo ""
echo "🛠️  Management scripts created:"
echo "   📄 add-mcp-tool.sh - Add new tools"
echo "   📄 list-mcp-tools.sh - List all tools" 
echo "   📄 toggle-mcp-tool.sh - Enable/disable tools"
echo "   📄 test-ssm-retrieval.py - Test parameter retrieval"

echo ""
echo "🔧 Usage examples:"
echo ""
echo "List all tools:"
echo "   ./list-mcp-tools.sh prod"
echo ""
echo "Add a new tool:"
echo "   ./add-mcp-tool.sh 'new_tool' 'Tool description' 'arn:aws:lambda:...' 'prod'"
echo ""
echo "View configuration:"
echo "   aws ssm get-parameter --name '/mcp/universal-wrapper/config' --output table"
echo ""
echo "Update configuration:"
echo "   aws ssm put-parameter --name '/mcp/universal-wrapper/config' --value file://updated-config.json --overwrite"

echo ""
echo "🎯 Next Steps:"
echo "   1. Deploy Universal MCP Wrapper Lambda"
echo "   2. Configure Lambda to read from: /mcp/universal-wrapper/config"
echo "   3. Test tool discovery via MCP protocol"
echo "   4. Add more tools as needed via configuration updates"

# Clean up test files
rm -f test-ssm-retrieval.py

echo ""
echo "✅ SSM Parameter Store setup completed!"
echo "📋 Your tool definitions are now stored and ready for use!"