# 🔧 MCP Gateway Authentication Troubleshooting Guide

## ❌ **Problem: Invalid Bearer Token Error**

You're encountering this error:
```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32001,
    "message": "Invalid Bearer token"
  }
}
```

This indicates a **gateway authentication configuration mismatch**.

---

## 🎯 **Root Cause Analysis**

The error suggests that:
1. **Gateway is configured for Bearer token authentication** (incorrect)
2. **We're sending AWS SigV4 authentication** (correct for IAM)
3. **Gateway expects IAM authentication but is misconfigured**

---

## 🚀 **Step-by-Step Resolution**

### **Step 1: Diagnose Authentication Methods**
Upload and run the diagnostic tool in CloudShell:

```bash
# Upload these files to CloudShell:
# - cloudshell_auth_diagnostic.sh
# - mcp_auth_diagnostic.py
# - gateway_config_checker.sh

# Make executable
chmod +x cloudshell_auth_diagnostic.sh
chmod +x gateway_config_checker.sh

# Run authentication diagnostic
./cloudshell_auth_diagnostic.sh
```

### **Step 2: Check Gateway Configuration**
```bash
# Check current gateway status
./gateway_config_checker.sh
```

### **Step 3: Verify Gateway Exists and is Properly Configured**
```bash
# Check if gateway exists in console
# AWS Console → Bedrock → Agent Core → Gateways
# Look for: a208194-askjulius-agentcore-mcp-gateway
```

### **Step 4: Fix Gateway Configuration**
If the gateway exists but has wrong auth config, you have two options:

**Option A: Recreate Gateway with Correct Config**
```bash
# Run the updated creation script
./create-agentcore-gateway.sh
```

**Option B: Manual Console Fix**
1. Go to AWS Console → Bedrock → Agent Core → Gateways
2. Find gateway: `a208194-askjulius-agentcore-mcp-gateway`
3. Edit configuration:
   - **Inbound Auth:** Set to `AWS_IAM` (not Bearer token)
   - **Outbound Auth:** Set to `AWS_IAM`
   - **Service Role:** Ensure correct role is assigned

---

## 🧪 **Testing After Fix**

### **Test 1: Authentication Diagnostic**
```bash
./cloudshell_auth_diagnostic.sh
```
**Expected:** At least one authentication method should succeed.

### **Test 2: Direct HTTP MCP Test**
```bash
python3 http_mcp_client_application_details.py test
```
**Expected:** Tools list should return successfully.

### **Test 3: Application Details Call**
```bash
python3 http_mcp_client_application_details.py a12345
```
**Expected:** Application details response without authentication errors.

---

## 📋 **Updated Gateway Configuration**

The corrected gateway configuration should use:

```json
{
  "gatewayName": "a208194-askjulius-agentcore-mcp-gateway",
  "gatewayConfiguration": {
    "semanticSearchEnabled": true,
    "inboundAuthConfig": {
      "type": "AWS_IAM"
    },
    "serviceRoleArn": "arn:aws:iam::818565325759:role/a208194-askjulius-agentcore-gateway"
  },
  "targets": [
    {
      "targetName": "a208194-application-details-tool-target",
      "targetDescription": "Details of the application based on the asset insight",
      "targetConfiguration": {
        "type": "MCP",
        "mcp": {
          "lambda": {
            "lambdaArn": "arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent",
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
                    "required": ["asset_id"],
                    "additionalProperties": false
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
```

**Key Changes:**
- `"type": "AWS_IAM"` instead of `"type": "IAM"`
- Proper service role configuration
- Correct MCP schema format

---

## 🔍 **Authentication Method Priority**

The diagnostic will test these methods in order:

1. **AWS SigV4 with bedrock-agentcore service** ← Most likely to work
2. **AWS SigV4 with bedrock service** ← Alternative
3. **AWS SigV4 with execute-api service** ← For API Gateway-style
4. **Bearer token with session token** ← If gateway expects Bearer
5. **Bearer token with access key** ← Alternative Bearer method
6. **No authentication** ← If gateway is open

---

## ✅ **Expected Successful Response**

After fixing authentication, you should see:

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

---

## 🚨 **If All Else Fails**

### **Complete Gateway Recreation:**
```bash
# 1. Delete existing gateway (if accessible)
# AWS Console → Bedrock → Agent Core → Gateways → Delete

# 2. Recreate with corrected configuration
./create-agentcore-gateway.sh

# 3. Wait for gateway to be fully deployed

# 4. Test with diagnostic
./cloudshell_auth_diagnostic.sh

# 5. Test application details
python3 http_mcp_client_application_details.py a12345
```

---

## 📞 **Support Commands**

```bash
# Check AWS credentials
aws sts get-caller-identity

# Check Lambda function
aws lambda get-function --function-name a208194-chatops_application_details_intent --region us-east-1

# Check service role
aws iam get-role --role-name a208194-askjulius-agentcore-gateway

# Test direct Lambda (bypass gateway)
aws lambda invoke --function-name a208194-chatops_application_details_intent --region us-east-1 --payload '{"asset_id":"a12345"}' response.json && cat response.json
```

---

## 🎯 **Success Criteria**

Authentication is fixed when:
- ✅ Diagnostic shows at least one successful auth method
- ✅ Tools list returns successfully
- ✅ Application details calls work without 401 errors
- ✅ No "Invalid Bearer token" messages

---

*💡 **Key Insight:** The issue is a gateway authentication configuration problem, not a client-side authentication problem. The gateway needs to be configured for `AWS_IAM` authentication instead of Bearer token authentication.*