# Fix MCP Gateway Lambda Integration - AWS Console UI Guide
# Step-by-step instructions to configure gateway via AWS Console

## 🎯 **Problem & Solution**
- **Issue**: Gateway returns `UnknownOperationException` 
- **Cause**: Gateway not configured to route to your Lambda function
- **Solution**: Add Lambda configuration via AWS Console

## 🌐 **Step 1: Access Bedrock Agent Core Console**

1. **Open AWS Console**: https://console.aws.amazon.com/
2. **Navigate to Bedrock**: Search for "Bedrock" in the services search
3. **Go to Agent Core**: Look for "Agent Core" or "Bedrock Agent Core"
   - If not visible, try: https://console.aws.amazon.com/bedrock/home?region=us-east-1#/
4. **Find Gateways Section**: Look for "Gateways" or "MCP Gateways"

## 🔍 **Step 2: Locate Your Gateway**

**Find your gateway:**
- **Gateway ID**: `a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59`
- **Gateway Name**: `a208194-askjulius-agentcore-gateway-mcp-iam`
- **Status**: Should show "READY"

**Click on your gateway** to open the configuration page.

## 🔧 **Step 3: Configure Lambda Integration**

### **Option A: If there's an "Edit" or "Configure" button:**

1. **Click "Edit Gateway"** or similar button
2. **Look for Lambda Configuration section**
3. **Add Lambda Function**:
   - **Function ARN**: `arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent`
   - **Or Function Name**: `a208194-chatops_application_details_intent`
4. **Save Changes**

### **Option B: If there's a "Lambda Configuration" tab:**

1. **Click "Lambda Configuration" tab**
2. **Add New Lambda Function**
3. **Enter Function Details**:
   - **Function ARN**: `arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent`
4. **Apply Configuration**

### **Option C: If there's an "Integration" section:**

1. **Find "Integration" or "Backend Configuration"**
2. **Select "Lambda Function"**
3. **Configure Target**:
   - **Function**: `a208194-chatops_application_details_intent`
   - **Region**: `us-east-1`
4. **Save Integration**

## ⚙️ **Step 4: Configure Lambda Permissions**

**Navigate to Lambda Console:**
1. **Open**: https://console.aws.amazon.com/lambda/home?region=us-east-1#/functions
2. **Search for**: `a208194-chatops_application_details_intent`
3. **Click on the function**

**Add Resource-Based Policy:**
1. **Go to "Configuration" tab**
2. **Click "Permissions" in left sidebar**
3. **Scroll to "Resource-based policy statements"**
4. **Click "Add permissions"**
5. **Configure permission**:
   - **Statement ID**: `bedrock-agentcore-invoke`
   - **Principal**: `bedrock-agentcore.amazonaws.com`
   - **Action**: `lambda:InvokeFunction`
6. **Save**

## 🧪 **Step 5: Test the Configuration**

**Back in Bedrock Agent Core console:**
1. **Find your gateway**
2. **Look for "Test" or "Try it" button**
3. **Send test request**:
   ```json
   {
     "jsonrpc": "2.0",
     "id": "test-1",
     "method": "tools/list",
     "params": {}
   }
   ```

**Expected Response:**
- Should return list of available tools
- No more `UnknownOperationException`

## 📋 **Alternative: CloudFormation/Infrastructure**

**If UI doesn't have gateway editing:**

1. **Go to CloudFormation console**
2. **Look for stack with your gateway**
3. **Update stack template** to include Lambda configuration
4. **Deploy update**

## 🔍 **Verification Steps**

**Check Gateway Status:**
1. **Gateway Status**: Should be "ACTIVE" (not just "READY")
2. **Lambda Configuration**: Should show your function ARN
3. **Last Updated**: Should show recent timestamp

**Test from Console:**
- Use the test functionality in the Bedrock console
- Send MCP protocol requests
- Verify responses from your Lambda function

## 🚨 **Troubleshooting UI Issues**

**If you can't find the gateway editing UI:**

1. **Check AWS Region**: Make sure you're in `us-east-1`
2. **Check Permissions**: Verify you have `bedrock-agentcore:UpdateGateway`
3. **Try Different Bedrock Sections**: 
   - Look in "Agents"
   - Check "Model Garden"
   - Try "Custom Models"
4. **Use Search**: Search for your gateway ID in the console

**Alternative Access Methods:**
- **Service Quotas**: Sometimes gateway management is under service quotas
- **IAM Console**: Check if there's a "Bedrock Agent Core" service
- **Resource Groups**: Search for resources by tag

## 📞 **If UI Method Doesn't Work**

**Fallback Options:**

1. **CLI Method**: Use the script we created (`fix-gateway-lambda.sh`)
2. **CloudShell**: Run commands directly in AWS CloudShell
3. **Support Case**: Create AWS support case for UI access

## ✅ **Success Indicators**

**You'll know it worked when:**
- ✅ Gateway status shows "ACTIVE"
- ✅ Lambda configuration visible in console
- ✅ Test requests return proper MCP responses
- ✅ No more `UnknownOperationException` errors

## 🎯 **Summary**

The key is to **add your Lambda function ARN** to the gateway configuration:
- **Function**: `arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent`
- **Permission**: Allow `bedrock-agentcore.amazonaws.com` to invoke
- **Test**: Verify MCP protocol responses

Once configured, your gateway will properly route MCP requests to your Lambda function instead of returning `UnknownOperationException`.