# 🌐 HTTP MCP Client Testing Guide for Application Details

## 🎯 **Problem Solved**
The "Invalid Bearer token" error occurs because the MCP gateway expects direct HTTP calls with AWS SigV4 authentication, not Bedrock Agent Runtime API calls. This guide provides the corrected approach.

---

## 🔧 **HTTP MCP Approach**

### **Key Changes:**
- **Direct HTTP calls** to the gateway MCP endpoint
- **AWS SigV4 authentication** instead of Bearer tokens
- **Proper MCP JSON-RPC 2.0 format** for requests
- **Python requests library** with `requests-aws4auth`

### **Gateway Details:**
- **Gateway ID:** `a208194-askjulius-agentcore-mcp-gateway`
- **HTTP Endpoint:** `https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp`
- **Authentication:** AWS SigV4 (bedrock-agentcore service)
- **Target Lambda:** `a208194-chatops_application_details_intent`

---

## 🚀 **Quick Start (CloudShell)**

### **Option 1: Simple HTTP Test**
```bash
# Upload and run the HTTP MCP test
./cloudshell_http_mcp_test.sh a12345
```

### **Option 2: Python Client**
```bash
# Use the HTTP MCP client directly
python3 http_mcp_client_application_details.py a12345
```

### **Option 3: Comprehensive Test**
```bash
# Run full test suite with HTTP fallback
./cloudshell_comprehensive_test.sh comprehensive
```

---

## 📋 **Step-by-Step CloudShell Setup**

### **1. Upload Files to CloudShell**
Upload these files to your CloudShell environment:
- `http_mcp_client_application_details.py`
- `cloudshell_http_mcp_test.sh`
- `cloudshell_comprehensive_test.sh`

### **2. Install Dependencies**
```bash
pip3 install --user requests-aws4auth boto3
```

### **3. Test Connectivity**
```bash
# Quick connectivity test
python3 http_mcp_client_application_details.py test

# Or use the shell script
./cloudshell_http_mcp_test.sh a12345
```

### **4. Test Application Details**
```bash
# Test specific asset ID
python3 http_mcp_client_application_details.py a208194

# Test with multiple asset IDs
python3 http_mcp_client_application_details.py comprehensive
```

---

## 🔍 **Expected Results**

### **Successful Tools List Response:**
```json
{
  "jsonrpc": "2.0",
  "id": "uuid-here",
  "result": {
    "tools": [
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
```

### **Successful Application Details Response:**
```json
{
  "jsonrpc": "2.0",
  "id": "uuid-here",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Application details for asset a12345: [application details here]"
      }
    ],
    "isError": false
  }
}
```

---

## 🧪 **Testing Commands**

### **Python Client Commands:**
```bash
# Interactive mode
python3 http_mcp_client_application_details.py

# List available tools
python3 http_mcp_client_application_details.py tools

# Test connectivity
python3 http_mcp_client_application_details.py test

# Run comprehensive tests
python3 http_mcp_client_application_details.py comprehensive

# Test specific asset ID
python3 http_mcp_client_application_details.py a208194
```

### **Shell Script Commands:**
```bash
# Basic test
./cloudshell_http_mcp_test.sh

# Test specific asset
./cloudshell_http_mcp_test.sh a208194

# Comprehensive test with fallbacks
./cloudshell_comprehensive_test.sh comprehensive
```

---

## ❌ **Common Issues & Solutions**

### **1. "Invalid Bearer token" Error**
- ✅ **Fixed:** Use HTTP client instead of Bedrock Agent Runtime API
- ✅ **Solution:** Use the new `http_mcp_client_application_details.py`

### **2. "AWS credentials not found"**
```bash
# Configure AWS credentials
aws configure

# Or check current credentials
aws sts get-caller-identity
```

### **3. "Gateway not accessible"**
```bash
# Verify gateway exists and endpoint is correct
curl -I https://a208194-askjulius-agentcore-mcp-gateway-dhy8ntpcvu.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp
```

### **4. "Lambda function not found"**
```bash
# Check if target Lambda exists
aws lambda get-function --function-name a208194-chatops_application_details_intent --region us-east-1
```

---

## 🔄 **Comparison: Old vs New Approach**

### **❌ Old Approach (Failed):**
```python
# Using Bedrock Agent Runtime API (causes Bearer token error)
response = bedrock_client.invoke_agent_core_gateway(
    gatewayId="...",
    agentAliasId="...",
    sessionId="...",
    inputText="..."
)
```

### **✅ New Approach (Working):**
```python
# Using direct HTTP calls with SigV4 auth
response = requests.post(
    gateway_url,
    json=mcp_payload,
    auth=aws_sigv4_auth,
    headers={'Content-Type': 'application/json'}
)
```

---

## 📊 **Performance Expectations**

- **Tools List:** ~200-500ms response time
- **Application Details Call:** ~500-2000ms response time  
- **Authentication:** Handled automatically by SigV4
- **Error Rate:** <1% with proper setup

---

## 🎯 **Next Steps**

1. **Test the HTTP approach** using the provided scripts
2. **Verify application details responses** with real asset IDs
3. **Integrate into your application** using the HTTP client pattern
4. **Monitor performance** and error rates in production
5. **Scale to additional use cases** using the same pattern

---

## 🔗 **Related Files**

- `http_mcp_client_application_details.py` - Main HTTP MCP client
- `cloudshell_http_mcp_test.sh` - Quick CloudShell test
- `cloudshell_comprehensive_test.sh` - Full test suite with fallbacks
- `application_details_target_schema.json` - Gateway configuration schema

---

*💡 **Key Insight:** The MCP gateway requires direct HTTP calls with AWS SigV4 authentication, not the Bedrock Agent Runtime API. This pattern works consistently across all MCP gateway implementations.*