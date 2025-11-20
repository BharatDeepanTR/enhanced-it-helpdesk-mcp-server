# 🔍 Calculator vs Application Details: Authentication Comparison

## 📊 **Summary: Why Calculator Worked vs Current "Invalid Bearer Token" Error**

### ✅ **Calculator Lambda - WORKING Authentication Pattern**

The calculator Lambda succeeded using **dual authentication approaches**:

#### **Method 1: Bedrock Agent Runtime API (Primary Success)**
```python
# This worked perfectly for calculator
response = bedrock_client.invoke_agent(
    agentId="a208194-calculator-mcp-server",  # Different gateway ID
    agentAliasId="TSTALIASID",
    sessionId=session_id,
    inputText="calculate 2 + 3"
)
```

#### **Method 2: Direct HTTP with SigV4 (Secondary Success)**
```python
# This also worked for calculator
auth = AWS4Auth(
    credentials.access_key,
    credentials.secret_key,
    region,
    'bedrock-agentcore',  # Key service name
    session_token=credentials.token
)

response = requests.post(
    calculator_gateway_url,  # Different endpoint
    json=mcp_request,
    auth=auth,
    headers={"Content-Type": "application/json"}
)
```

### ❌ **Application Details - CURRENT ISSUE**

Application details is failing with "Invalid Bearer token" because:

#### **Root Cause Analysis:**

1. **Different Gateway Instance:**
   - Calculator: `a208194-calculator-mcp-server`
   - App Details: `a208194-askjulius-agentcore-mcp-gateway`
   - **Different gateways = Different authentication configurations**

2. **Authentication Method Mismatch:**
   - Calculator gateway: Configured for AWS SigV4 (works with `bedrock-agentcore` service)
   - App Details gateway: Might be configured for Bearer token authentication
   - **Same auth code, different gateway expectations**

3. **Only Trying HTTP Method:**
   - Calculator: Had both Agent API and HTTP approaches
   - App Details: Only trying HTTP (missing the Agent API approach)

## 🔧 **Solution: Dual Authentication Approach**

The new `dual_auth_application_details_client.py` implements **both working patterns**:

### **Pattern 1: Bedrock Agent Runtime API**
```python
# Same approach that worked for calculator
response = self.bedrock_client.invoke_agent(
    agentId=self.gateway_id,  # a208194-askjulius-agentcore-mcp-gateway
    agentAliasId="TSTALIASID",  # Same alias as calculator
    sessionId=self.session_id,
    inputText=f"Get application details for asset {asset_id}"
)
```

### **Pattern 2: HTTP with SigV4 Fallback**
```python
# Same auth as calculator, but with application details gateway
auth = AWS4Auth(
    credentials.access_key,
    credentials.secret_key,
    region,
    'bedrock-agentcore',  # Same service name that worked for calculator
    session_token=credentials.token
)

response = requests.post(
    self.gateway_url,  # Application details gateway endpoint
    json=payload,
    auth=auth,
    headers=headers
)
```

## 📈 **Expected Outcome**

1. **Agent Runtime API will likely succeed** (primary method that worked for calculator)
2. **HTTP method might still fail** with Bearer token error (different gateway config)
3. **At least one method should work** - giving us a functional MCP client

## 🎯 **Key Insights**

1. **Gateway-Specific Authentication:** Different Agent Core gateways can have different authentication requirements
2. **Multi-Method Resilience:** Calculator's success came from having multiple authentication approaches
3. **Service Name Consistency:** `bedrock-agentcore` service name works for AWS SigV4 when supported
4. **Agent API Reliability:** Bedrock Agent Runtime API seems more consistent across gateways

## 🚀 **Next Steps**

1. **Deploy Dual Auth Client:** Use the CloudShell deployment script
2. **Test Both Methods:** See which authentication approach works
3. **Gateway Investigation:** If both fail, investigate gateway configuration differences
4. **Successful Pattern Replication:** Once working, document the successful pattern for future use

## 📝 **Files Created**

- `dual_auth_application_details_client.py` - Main client with both auth methods
- `cloudshell_deploy_dual_auth.sh` - CloudShell deployment script
- `CALCULATOR-VS-APPDETAILS-COMPARISON.md` - This comparison document

The dual authentication approach ensures we have the same resilience that made the calculator Lambda integration successful.