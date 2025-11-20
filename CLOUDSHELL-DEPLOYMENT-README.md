# 🚀 CloudShell Application Details MCP Client

**Comprehensive solution for connecting to the Agent Core Gateway from CloudShell**

## 🎯 **Problem Statement**

We encountered two critical issues when trying to connect to the Application Details gateway:

1. **Agent ID Validation Error**: `Value 'a208194-askjulius-agentcore-mcp-gateway' at 'agentId' failed to satisfy constraint`
2. **Bearer Token Authentication Error**: `{"error":{"code":-32001,"message":"Invalid Bearer token"}}`
3. **CRITICAL: Wrong Gateway**: We were testing with `a208194-askjulius-agentcore-mcp-gateway` instead of the correct IAM-configured gateway `a208194-askjulius-agentcore-gateway-mcp-iam`

## ✅ **Solution Overview**

This CloudShell deployment package provides:
- ✅ **Fixed Agent ID Issue**: No longer uses gateway name as agent ID
- ✅ **Multiple Authentication Methods**: Tests SigV4 and Bearer token approaches
- ✅ **Comprehensive Testing**: Direct Lambda + Gateway + MCP tool calls
- ✅ **CloudShell Optimized**: Handles AWS credentials automatically
- ✅ **Detailed Diagnostics**: Clear error reporting and troubleshooting

## 🚀 **Quick Start (CloudShell)**

### Option 1: Corrected Gateway Test (RECOMMENDED)
```bash
# Test with the CORRECT IAM-configured gateway:
chmod +x cloudshell_test_correct_gateway.sh
./cloudshell_test_correct_gateway.sh
```

### Option 2: One-Command Deployment
```bash
# Copy and paste this entire command into CloudShell:
wget -O deploy.sh https://raw.githubusercontent.com/[your-repo]/cloudshell_comprehensive_deployment.sh && chmod +x deploy.sh && ./deploy.sh
```

### Option 3: Manual Deployment
```bash
# 1. Copy the deployment script to CloudShell
# 2. Make executable and run:
chmod +x cloudshell_comprehensive_deployment.sh
./cloudshell_comprehensive_deployment.sh
```

### Option 3: Quick Test (Copy-Paste)
Use the content from `cloudshell_quick_deploy.txt` for a minimal setup.

## 📁 **Files in this Package**

### Core Files
- **`cloudshell_test_correct_gateway.sh`** - **NEW: Tests CORRECT IAM-configured gateway**
- **`cloudshell_comprehensive_deployment.sh`** - Main deployment script (updated)
- **`cloudshell_quick_deploy.txt`** - Copy-paste ready quick deployment

### Reference Files
- **`dual_auth_application_details_client.py`** - Original dual-auth client
- **`corrected_application_details_client.py`** - Fixed version addressing Agent ID issue
- **`CALCULATOR-VS-APPDETAILS-COMPARISON.md`** - Analysis of why calculator worked vs current issues

### Documentation
- **`CLOUDSHELL-DEPLOYMENT-README.md`** - This file
- Various troubleshooting and authentication diagnostic files

## 🧪 **What the Test Does**

The comprehensive test suite performs:

### 1. **Direct Lambda Test**
- Tests `a208194-chatops_application_details_intent` Lambda directly
- Verifies the Lambda function is working independently
- Baseline to isolate gateway vs Lambda issues

### 2. **Gateway Connectivity Test**
- Tests multiple gateway endpoints: `/mcp`, `/invoke`, `/tools`, `/api`, root
- Identifies which endpoints are accessible
- HTTP status code analysis

### 3. **Authentication Method Testing**
Tests multiple authentication approaches:
- **SigV4** with services: `bedrock-agentcore`, `bedrock`, `execute-api`
- **Bearer Token** with formats: session token, access key, combined
- **No Auth** (baseline test)

### 4. **MCP Tools List Test**
- Calls `tools/list` method to verify MCP protocol works
- Identifies working authentication method
- Lists available tools in the gateway

### 5. **Application Details Tool Call**
- Calls `get_application_details` with test asset IDs
- Uses the successful authentication method from previous tests
- Verifies end-to-end functionality

## 📊 **Expected Outcomes**

### ✅ **BEST CASE: Full Success**
```
✅ Direct Lambda invocation: WORKING
✅ Gateway connectivity: 5 endpoints accessible
✅ Gateway authentication: WORKING (sigv4_bedrock-agentcore)
✅ Application details tool call: WORKING
```

### ⚠️ **PARTIAL SUCCESS: Lambda Works, Gateway Fails**
```
✅ Direct Lambda invocation: WORKING
✅ Gateway connectivity: 5 endpoints accessible
❌ Gateway authentication: FAILED on all methods
```
**Diagnosis**: Gateway configuration issue (authentication settings)

### ❌ **FAILURE: Network/Permissions Issue**
```
❌ Direct Lambda invocation: FAILED
❌ Gateway connectivity: No endpoints accessible
❌ Gateway authentication: FAILED
```
**Diagnosis**: AWS credentials, permissions, or network connectivity issue

## 🔧 **Usage Commands**

After deployment, use these commands:

```bash
# Full comprehensive test
python3 cloudshell_app_details_client.py test

# Test direct Lambda only
python3 cloudshell_app_details_client.py lambda

# Test gateway connectivity only  
python3 cloudshell_app_details_client.py connectivity

# Quick test for specific asset
python3 cloudshell_app_details_client.py asset a12345
```

## 🛠️ **Troubleshooting**

### Issue: "Module not found: boto3"
```bash
pip3 install --user requests-aws4auth boto3
```

### Issue: "No AWS credentials found"
```bash
aws sts get-caller-identity  # Verify credentials
aws configure list           # Check configuration
```

### Issue: "All authentication methods failed"
- Check IAM permissions for your user/role
- Verify gateway configuration in AWS Console
- Check if gateway exists and is active

### Issue: "Lambda works but gateway doesn't"
- Gateway authentication configuration mismatch
- Check gateway's inbound/outbound auth settings
- Verify service role permissions

## 📋 **Gateway Configuration Reference**

Current gateway settings (CORRECTED):
```
Gateway Name: a208194-askjulius-agentcore-gateway-mcp-iam
Gateway ID: a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59
Gateway URL: https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com
Lambda ARN: arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent
Region: us-east-1
Authentication: IAM (SigV4)
```

❌ **Previous WRONG gateway**: `a208194-askjulius-agentcore-mcp-gateway`
✅ **Current CORRECT gateway**: `a208194-askjulius-agentcore-gateway-mcp-iam`

Expected tool schema:
```json
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
```

## 🔄 **Next Steps Based on Results**

### If Authentication Works ✅
1. Use the working authentication method for production clients
2. Document the successful pattern
3. Create optimized client using only the working method

### If Authentication Fails ❌
1. Check gateway configuration in AWS Console
2. Verify inbound/outbound authentication settings
3. Compare with working calculator gateway configuration
4. Consider recreating gateway with correct auth settings

### If Only Direct Lambda Works ⚠️
1. Gateway configuration issue confirmed
2. Check service role permissions
3. Verify gateway target configuration
4. May need to recreate gateway

## 📞 **Support**

If all tests fail:
1. Check AWS credentials: `aws sts get-caller-identity`
2. Verify permissions: Can you access other AWS services?
3. Check network connectivity: Are you behind a firewall?
4. Verify gateway exists: Check AWS Console → Bedrock → Agent Core → Gateways

The comprehensive testing will help isolate whether the issue is:
- **Client-side**: Credentials, network, permissions
- **Gateway-side**: Configuration, authentication settings
- **Lambda-side**: Function issues, permissions