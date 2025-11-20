# 📋 SSM Parameter Store for MCP Tool Definitions - Quick Guide

## 🎯 **What is SSM Parameter Store?**

AWS Systems Manager Parameter Store is a secure, hierarchical storage for configuration data and secrets. For MCP tools, we use it to store JSON configurations that define which Lambda functions are available as MCP tools.

---

## 🔧 **Basic SSM Operations**

### **1. Store Tool Configuration**

```bash
# Create your tool configuration JSON file
cat > mcp-config.json << 'EOF'
{
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
      "output_format": "json",
      "enabled": true
    }
  ]
}
EOF

# Store in SSM Parameter Store
aws ssm put-parameter \
  --name "/mcp/universal-wrapper/config" \
  --value file://mcp-config.json \
  --type "String" \
  --description "Universal MCP Wrapper tool configuration" \
  --overwrite
```

### **2. Retrieve Configuration**

```bash
# Get parameter value
aws ssm get-parameter \
  --name "/mcp/universal-wrapper/config" \
  --query 'Parameter.Value' \
  --output text

# Get with metadata
aws ssm get-parameter \
  --name "/mcp/universal-wrapper/config" \
  --output table
```

### **3. Update Configuration**

```bash
# Method 1: Update entire configuration
aws ssm put-parameter \
  --name "/mcp/universal-wrapper/config" \
  --value file://updated-config.json \
  --overwrite

# Method 2: Direct JSON update
aws ssm put-parameter \
  --name "/mcp/universal-wrapper/config" \
  --value '{"tools":[{"name":"new_tool","lambda_arn":"arn:..."}]}' \
  --overwrite
```

### **4. List Parameters**

```bash
# List all MCP-related parameters
aws ssm describe-parameters \
  --filters "Key=Name,Values=/mcp/" \
  --query 'Parameters[].Name' \
  --output table
```

---

## 📊 **Configuration Structure**

### **Complete Configuration Example:**

```json
{
  "description": "Universal MCP Wrapper Configuration",
  "version": "1.0",
  "last_updated": "2025-11-12",
  "tools": [
    {
      "name": "get_application_details",
      "description": "Get application details including name, contact, and regional presence",
      "lambda_arn": "arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent",
      "input_schema": {
        "type": "object",
        "properties": {
          "asset_id": {
            "type": "string",
            "description": "Application asset ID"
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
    },
    {
      "name": "send_notification",
      "description": "Send notification to users",
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
      "input_mapping": {
        "recipient": "email",
        "message": "messageText",
        "priority": "urgency"
      },
      "output_format": "text",
      "enabled": true
    }
  ]
}
```

---

## 🔧 **Environment-Specific Configurations**

### **Multiple Environments:**

```bash
# Development environment
aws ssm put-parameter \
  --name "/mcp/universal-wrapper/config/dev" \
  --value file://dev-config.json \
  --type "String"

# Staging environment  
aws ssm put-parameter \
  --name "/mcp/universal-wrapper/config/staging" \
  --value file://staging-config.json \
  --type "String"

# Production environment
aws ssm put-parameter \
  --name "/mcp/universal-wrapper/config/prod" \
  --value file://prod-config.json \
  --type "String"
```

### **Lambda Environment Variable Setup:**

```bash
# Configure Lambda to use specific environment
aws lambda update-function-configuration \
  --function-name "universal-mcp-wrapper" \
  --environment Variables='{
    "MCP_CONFIG_PARAMETER": "/mcp/universal-wrapper/config/prod",
    "ENVIRONMENT": "production"
  }'
```

---

## 🧩 **How Lambda Reads SSM Parameters**

### **Python Code in Lambda:**

```python
import boto3
import json
import os

def load_configuration():
    """Load MCP tool configuration from SSM Parameter Store"""
    
    ssm_client = boto3.client('ssm')
    
    # Get parameter name from environment variable
    parameter_name = os.environ.get('MCP_CONFIG_PARAMETER', '/mcp/universal-wrapper/config')
    
    try:
        response = ssm_client.get_parameter(
            Name=parameter_name,
            WithDecryption=True
        )
        
        config_json = response['Parameter']['Value']
        config = json.loads(config_json)
        
        print(f"Loaded {len(config.get('tools', []))} tools from {parameter_name}")
        return config
        
    except Exception as e:
        print(f"Error loading configuration: {e}")
        return {"tools": []}

# Usage in lambda_handler
def lambda_handler(event, context):
    config = load_configuration()
    tools = config.get('tools', [])
    
    # Process MCP request using loaded tools...
```

---

## 📝 **Configuration Management Best Practices**

### **1. Versioning and Backups**

```bash
# Create timestamped backup before changes
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Backup current configuration
aws ssm get-parameter \
  --name "/mcp/universal-wrapper/config" \
  --query 'Parameter.Value' \
  --output text > backup-$TIMESTAMP.json

# Store backup as new parameter
aws ssm put-parameter \
  --name "/mcp/universal-wrapper/config/backup/$TIMESTAMP" \
  --value file://backup-$TIMESTAMP.json \
  --type "String" \
  --description "Configuration backup created $TIMESTAMP"
```

### **2. Validation**

```bash
# Validate JSON syntax before storing
jq empty mcp-config.json && echo "✅ Valid JSON" || echo "❌ Invalid JSON"

# Test configuration loading
python3 -c "
import json
with open('mcp-config.json', 'r') as f:
    config = json.load(f)
    print(f'✅ Configuration valid: {len(config[\"tools\"])} tools')
    for tool in config['tools']:
        print(f'  • {tool[\"name\"]}: {tool[\"lambda_arn\"]}')
"
```

### **3. Parameter Hierarchy**

```
/mcp/
├── universal-wrapper/
│   ├── config                    # Default/production config
│   ├── config/dev               # Development environment
│   ├── config/staging           # Staging environment  
│   ├── config/prod              # Production environment
│   └── config/backup/
│       ├── 20251112_143022      # Timestamped backups
│       └── 20251112_150815
└── other-wrappers/
    └── specialized-wrapper/
        └── config
```

---

## 🎯 **Quick Commands Reference**

```bash
# Store configuration
aws ssm put-parameter --name "/mcp/universal-wrapper/config" --value file://config.json --type "String" --overwrite

# Get configuration  
aws ssm get-parameter --name "/mcp/universal-wrapper/config" --query 'Parameter.Value' --output text

# List MCP parameters
aws ssm describe-parameters --filters "Key=Name,Values=/mcp/" --query 'Parameters[].Name' --output table

# Delete parameter
aws ssm delete-parameter --name "/mcp/universal-wrapper/config/old"

# Get parameter metadata
aws ssm describe-parameters --filters "Key=Name,Values=/mcp/universal-wrapper/config"
```

---

## ✅ **Benefits of Using SSM Parameter Store**

1. **🔒 Secure**: Built-in encryption and access control
2. **🏗️ Hierarchical**: Organized parameter structure  
3. **📝 Versioned**: Parameter history and rollback capability
4. **🌍 Regional**: Region-specific configurations
5. **🔧 No Restart**: Lambda picks up changes without restart
6. **💰 Cost-Effective**: No additional infrastructure needed
7. **🎯 IAM Integration**: Fine-grained access permissions

This approach lets you manage all your MCP tool configurations centrally without deploying new code!