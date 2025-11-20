#!/bin/bash
# CloudShell: Quick Setup for SSM Parameter Store MCP Configuration
# Ready-to-use commands for your specific Lambda function

echo "⚡ Quick SSM Setup for Your MCP Configuration"
echo "==========================================="
echo ""

# Your specific configuration
LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"
PARAMETER_NAME="/mcp/universal-wrapper/config"

echo "🎯 Setting up SSM Parameter Store for:"
echo "   Lambda Function: $LAMBDA_ARN"
echo "   Parameter Name: $PARAMETER_NAME"
echo ""

echo "🔧 Step 1: Create Configuration JSON"
echo "==================================="

# Create your specific configuration
cat > your-mcp-config.json << EOF
{
  "description": "MCP Configuration for a208194 Application Details Service",
  "version": "1.0",
  "environment": "production",
  "last_updated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "tools": [
    {
      "name": "get_application_details",
      "description": "Get application details including name, contact, and regional presence for a given asset ID",
      "lambda_arn": "$LAMBDA_ARN",
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
      "retry_count": 2,
      "enabled": true,
      "tags": ["application", "details", "chatops"]
    }
  ],
  "global_settings": {
    "default_timeout": 30,
    "max_retry_count": 3,
    "log_level": "INFO"
  }
}
EOF

echo "✅ Configuration file created: your-mcp-config.json"

echo ""
echo "📄 Configuration preview:"
cat your-mcp-config.json | jq . 2>/dev/null || cat your-mcp-config.json

echo ""
echo "🔧 Step 2: Store in SSM Parameter Store"
echo "====================================="

echo "Storing configuration in SSM..."

aws ssm put-parameter \
  --name "$PARAMETER_NAME" \
  --value file://your-mcp-config.json \
  --type "String" \
  --description "Universal MCP Wrapper configuration for a208194 application details service" \
  --overwrite \
  --tags "Key=Service,Value=MCP" "Key=Environment,Value=Production" "Key=Application,Value=a208194" \
  --output table

STORE_RESULT=$?

if [ $STORE_RESULT -eq 0 ]; then
    echo ""
    echo "🎉 SUCCESS! Configuration stored in SSM Parameter Store!"
else
    echo ""
    echo "❌ Failed to store configuration"
    exit 1
fi

echo ""
echo "🔧 Step 3: Verify Storage"
echo "======================"

echo "Retrieving and verifying stored configuration..."

# Get parameter info
echo "📊 Parameter metadata:"
aws ssm describe-parameters \
  --filters "Key=Name,Values=$PARAMETER_NAME" \
  --query 'Parameters[0].{Name:Name,Type:Type,Description:Description,LastModifiedDate:LastModifiedDate}' \
  --output table

# Get parameter value
echo ""
echo "📄 Stored configuration:"
aws ssm get-parameter \
  --name "$PARAMETER_NAME" \
  --query 'Parameter.Value' \
  --output text | jq . 2>/dev/null

echo ""
echo "🔧 Step 4: Test Parameter Retrieval (Lambda Simulation)"
echo "===================================================="

echo "Testing how Lambda would retrieve this configuration..."

# Create test Python script
cat > test-ssm-retrieval-simulation.py << 'TEST_EOF'
import boto3
import json
import os

def test_mcp_config_retrieval():
    """Simulate how Universal MCP Wrapper Lambda would retrieve configuration"""
    
    # Simulate environment variable
    os.environ['MCP_CONFIG_PARAMETER'] = '/mcp/universal-wrapper/config'
    
    ssm_client = boto3.client('ssm', region_name='us-east-1')
    parameter_name = os.environ.get('MCP_CONFIG_PARAMETER')
    
    print(f"🔍 Lambda would retrieve parameter: {parameter_name}")
    
    try:
        response = ssm_client.get_parameter(
            Name=parameter_name,
            WithDecryption=True
        )
        
        config_json = response['Parameter']['Value']
        config = json.loads(config_json)
        
        print("✅ Configuration successfully retrieved!")
        print(f"📊 Summary:")
        print(f"   Description: {config.get('description', 'N/A')}")
        print(f"   Version: {config.get('version', 'N/A')}")
        print(f"   Environment: {config.get('environment', 'N/A')}")
        print(f"   Tools count: {len(config.get('tools', []))}")
        
        print(f"\n📋 Available MCP tools:")
        for i, tool in enumerate(config.get('tools', []), 1):
            status = "🟢 Enabled" if tool.get('enabled', True) else "🔴 Disabled"
            print(f"   {i}. {tool['name']} [{status}]")
            print(f"      Description: {tool['description']}")
            print(f"      Lambda ARN: {tool['lambda_arn']}")
            print(f"      Input Schema: {tool['input_schema']['properties']}")
            if tool.get('input_mapping'):
                print(f"      Input Mapping: {tool['input_mapping']}")
            print()
        
        # Test tools/list response generation
        tools_list_response = {
            "jsonrpc": "2.0",
            "id": "test",
            "result": {
                "tools": [
                    {
                        "name": tool['name'],
                        "description": tool['description'],
                        "inputSchema": tool['input_schema']
                    }
                    for tool in config.get('tools', [])
                    if tool.get('enabled', True)
                ]
            }
        }
        
        print("🧪 Simulated MCP tools/list response:")
        print(json.dumps(tools_list_response, indent=2))
        
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    success = test_mcp_config_retrieval()
    if success:
        print("\n🎉 SSM Parameter Store configuration is working correctly!")
    else:
        print("\n❌ Configuration issues detected")
TEST_EOF

echo "Running Lambda simulation test..."
python3 test-ssm-retrieval-simulation.py

echo ""
echo "🔧 Step 5: Create Configuration Management Commands"
echo "================================================"

echo "Creating helper commands for ongoing management..."

# Quick commands file
cat > ssm-management-commands.sh << 'MGMT_EOF'
#!/bin/bash
# SSM Parameter Store Management Commands for MCP Configuration

PARAMETER_NAME="/mcp/universal-wrapper/config"

# Function to display current configuration
view_config() {
    echo "📄 Current MCP Configuration:"
    echo "=============================="
    aws ssm get-parameter \
        --name "$PARAMETER_NAME" \
        --query 'Parameter.Value' \
        --output text | jq . 2>/dev/null
}

# Function to backup configuration
backup_config() {
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_NAME="/mcp/universal-wrapper/config/backup/$TIMESTAMP"
    
    echo "💾 Creating backup: $BACKUP_NAME"
    
    # Get current config
    CURRENT_CONFIG=$(aws ssm get-parameter --name "$PARAMETER_NAME" --query 'Parameter.Value' --output text)
    
    # Store backup
    aws ssm put-parameter \
        --name "$BACKUP_NAME" \
        --value "$CURRENT_CONFIG" \
        --type "String" \
        --description "Backup created on $TIMESTAMP" \
        --tags "Key=Type,Value=Backup" "Key=CreatedDate,Value=$(date)"
    
    echo "✅ Backup created: $BACKUP_NAME"
}

# Function to list backups
list_backups() {
    echo "📋 Available Backups:"
    echo "===================="
    aws ssm describe-parameters \
        --filters "Key=Name,Values=/mcp/universal-wrapper/config/backup/" \
        --query 'Parameters[].[Name,Description,LastModifiedDate]' \
        --output table
}

# Function to restore from backup
restore_backup() {
    if [ $# -eq 0 ]; then
        echo "Usage: restore_backup <backup_parameter_name>"
        echo "Use list_backups to see available backups"
        return 1
    fi
    
    BACKUP_NAME="$1"
    
    echo "🔄 Restoring from backup: $BACKUP_NAME"
    
    # Get backup content
    BACKUP_CONFIG=$(aws ssm get-parameter --name "$BACKUP_NAME" --query 'Parameter.Value' --output text)
    
    if [ $? -eq 0 ]; then
        # Create current backup before restore
        backup_config
        
        # Restore backup
        aws ssm put-parameter \
            --name "$PARAMETER_NAME" \
            --value "$BACKUP_CONFIG" \
            --type "String" \
            --description "Restored from $BACKUP_NAME on $(date)" \
            --overwrite
        
        echo "✅ Configuration restored from backup"
    else
        echo "❌ Failed to retrieve backup"
    fi
}

# Show usage if no arguments
if [ $# -eq 0 ]; then
    echo "🔧 MCP Configuration Management Commands:"
    echo "========================================"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  view        - View current configuration"
    echo "  backup      - Create backup of current configuration"
    echo "  list        - List available backups"
    echo "  restore     - Restore from backup (requires backup name)"
    echo ""
    echo "Examples:"
    echo "  $0 view"
    echo "  $0 backup"
    echo "  $0 list"
    echo "  $0 restore /mcp/universal-wrapper/config/backup/20251112_143022"
    exit 1
fi

# Execute command
case "$1" in
    view)
        view_config
        ;;
    backup)
        backup_config
        ;;
    list)
        list_backups
        ;;
    restore)
        restore_backup "$2"
        ;;
    *)
        echo "❌ Unknown command: $1"
        echo "Use: $0 (no arguments) to see usage"
        exit 1
        ;;
esac
MGMT_EOF

chmod +x ssm-management-commands.sh

echo "✅ Management commands created: ssm-management-commands.sh"

echo ""
echo "🔧 Step 6: Lambda Environment Configuration"
echo "=========================================="

echo "Setting up Lambda environment to use this SSM parameter..."

# This would be used when deploying the Universal MCP Wrapper
cat > lambda-environment-config.json << ENV_EOF
{
  "Variables": {
    "MCP_CONFIG_PARAMETER": "$PARAMETER_NAME",
    "MCP_CONFIG_CACHE_TTL": "300",
    "AWS_DEFAULT_REGION": "us-east-1",
    "LOG_LEVEL": "INFO"
  }
}
ENV_EOF

echo "✅ Lambda environment configuration ready: lambda-environment-config.json"

# Clean up test file
rm -f test-ssm-retrieval-simulation.py

echo ""
echo "📋 QUICK SETUP COMPLETE!"
echo "========================"

echo ""
echo "✅ What's been created:"
echo "   📄 SSM Parameter: $PARAMETER_NAME"
echo "   📄 Configuration file: your-mcp-config.json"
echo "   📄 Management script: ssm-management-commands.sh"
echo "   📄 Lambda environment: lambda-environment-config.json"

echo ""
echo "🚀 Quick Usage Commands:"
echo ""
echo "View configuration:"
echo "   ./ssm-management-commands.sh view"
echo ""
echo "Create backup:"
echo "   ./ssm-management-commands.sh backup"
echo ""
echo "Update configuration:"
echo "   # Edit your-mcp-config.json, then:"
echo "   aws ssm put-parameter --name '$PARAMETER_NAME' --value file://your-mcp-config.json --overwrite"
echo ""
echo "Test Lambda retrieval:"
echo "   aws ssm get-parameter --name '$PARAMETER_NAME' --query 'Parameter.Value' --output text | jq ."

echo ""
echo "🎯 Next Steps:"
echo "   1. Deploy Universal MCP Wrapper Lambda"
echo "   2. Configure Lambda environment variables from lambda-environment-config.json"
echo "   3. Test MCP protocol with your configuration"
echo "   4. Add more tools by updating the SSM parameter"

echo ""
echo "✅ Your MCP configuration is ready to use!"