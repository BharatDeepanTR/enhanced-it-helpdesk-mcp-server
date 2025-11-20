# 🚀 CloudShell Setup Instructions for Application Details Gateway Testing

## 📋 **Overview**
This guide helps you test the Application Details MCP integration using AWS CloudShell, which provides a pre-configured environment with AWS CLI and necessary tools.

---

## 🔧 **Step 1: Access AWS CloudShell**

1. **Login to AWS Console**
   - Go to your AWS account console
   - Ensure you're in the **us-east-1** region

2. **Open CloudShell**
   - Click the CloudShell icon (terminal) in the top navigation bar
   - Wait for CloudShell to initialize (about 30 seconds)

3. **Verify Access**
   ```bash
   aws sts get-caller-identity
   ```
   - Should show your account ID and user/role information

---

## 📁 **Step 2: Upload Test Scripts**

**Option A: Copy-Paste Method**

1. Create the quick test script:
   ```bash
   cat > cloudshell_quick_test.sh << 'EOF'
   [Copy content from cloudshell_quick_test.sh]
   EOF
   ```

2. Make it executable:
   ```bash
   chmod +x cloudshell_quick_test.sh
   ```

**Option B: Upload Files**
1. Use CloudShell's upload feature (Actions → Upload file)
2. Upload these files:
   - `cloudshell_quick_test.sh`
   - `cloudshell_comprehensive_test.sh` 
   - `application_details_test_data.json`

---

## ⚡ **Step 3: Quick Test**

Run the quick test to verify basic functionality:

```bash
# Test with default asset ID (a12345)
./cloudshell_quick_test.sh

# Test with specific asset ID
./cloudshell_quick_test.sh a208194

# Test with numeric asset ID (auto-prefixed)
./cloudshell_quick_test.sh 12345
```

**Expected Output:**
```
🔍 Quick Application Details Test
================================
Asset ID: a12345
Gateway: a208194-askjulius-agentcore-gateway-mcp-iam

🔧 Checking AWS access...
✅ AWS Account: 818565325759

📤 Creating test payload...
🚀 Testing gateway invocation...
✅ Gateway invocation successful!

📥 Response:
[JSON response with application details]
```

---

## 🧪 **Step 4: Comprehensive Testing**

Run the full test suite:

```bash
# Make comprehensive script executable
chmod +x cloudshell_comprehensive_test.sh

# Run all test cases
./cloudshell_comprehensive_test.sh comprehensive

# Run connectivity checks only
./cloudshell_comprehensive_test.sh check

# Test specific asset ID
./cloudshell_comprehensive_test.sh test a208194

# Test direct Lambda (bypass gateway)
./cloudshell_comprehensive_test.sh lambda a12345
```

---

## 🔍 **Step 5: Manual Gateway Testing**

If scripts fail, test manually:

```bash
# Create test payload
cat > manual_test.json << EOF
{
    "gatewayId": "a208194-askjulius-agentcore-gateway-mcp-iam",
    "agentAliasId": "TSTALIASID",
    "sessionId": "manual-test-$(date +%s)",
    "inputText": "Get application details for asset a12345",
    "endSession": false
}
EOF

# Invoke gateway
aws bedrock-agent-runtime invoke-agent-core-gateway \
    --cli-input-json file://manual_test.json \
    --region us-east-1 \
    --output json
```

---

## 🔧 **Step 6: Direct Lambda Testing**

Test the Lambda function directly:

```bash
# Create Lambda payload
cat > lambda_test.json << EOF
{
    "asset_id": "a12345"
}
EOF

# Invoke Lambda directly
aws lambda invoke \
    --function-name a208194-chatops_application_details_intent \
    --region us-east-1 \
    --payload file://lambda_test.json \
    lambda_response.json

# View response
cat lambda_response.json | jq .
```

---

## 📊 **Step 7: Verify Gateway Configuration**

Check if the gateway exists and is configured:

```bash
# List gateways (if command is available)
aws bedrock-agent-runtime list-agent-core-gateways --region us-east-1 2>/dev/null || \
echo "Gateway list command not available in this CLI version"

# Check service role
aws iam get-role --role-name a208194-askjulius-agentcore-gateway

# Check Lambda function
aws lambda get-function --function-name a208194-chatops_application_details_intent --region us-east-1
```

---

## ❓ **Troubleshooting**

### **Common Issues:**

1. **"Gateway not found" error**
   ```bash
   # Check if gateway exists in console
   # AWS Console → Bedrock → Agent Core → Gateways
   ```

2. **"Access denied" error**
   ```bash
   # Check IAM permissions
   aws sts get-caller-identity
   aws iam list-attached-role-policies --role-name a208194-askjulius-agentcore-gateway
   ```

3. **"Lambda function not found"**
   ```bash
   # Verify Lambda exists
   aws lambda list-functions --region us-east-1 | grep a208194-chatops_application_details_intent
   ```

4. **"Invalid agent alias" error**
   - Try different agent alias IDs:
     - `TSTALIASID` (default)
     - `$LATEST`
     - `DRAFT`

### **Alternative Commands:**

If `bedrock-agent-runtime` doesn't work, try:
```bash
# Alternative 1
aws bedrock invoke-agent-core-gateway [params]

# Alternative 2  
aws bedrock-agent invoke-gateway [params]

# Alternative 3
aws bedrock-runtime invoke-agent-core-gateway [params]
```

---

## 🎯 **Expected Test Results**

### **Successful Gateway Response:**
```json
{
    "completion": "Application details for asset a12345: [details here]",
    "sessionId": "test-session-123",
    "responseMetadata": { ... }
}
```

### **Successful Lambda Response:**
```json
{
    "statusCode": 200,
    "body": {
        "asset_id": "a12345",
        "application_name": "Example App",
        "contact_info": "admin@example.com",
        "regional_presence": ["us-east-1", "us-west-2"]
    }
}
```

---

## 📞 **Next Steps**

Once testing is successful:

1. **Document results** for your team
2. **Scale to production** asset IDs
3. **Integrate with your application** using the proven patterns
4. **Monitor performance** and error rates
5. **Expand to additional use cases**

---

## 🔗 **Related Files**

- `cloudshell_quick_test.sh` - Simple gateway test
- `cloudshell_comprehensive_test.sh` - Full test suite  
- `application_details_test_data.json` - Test case data
- `mcp_client_application_details.py` - Python client (requires boto3)
- `application_details_target_schema.json` - Gateway configuration schema

---

*💡 **Pro Tip:** Start with the quick test, then move to comprehensive testing once basic connectivity is confirmed.*