# AWS CLI Agent Core Gateway Commands - OFFICIAL TROUBLESHOOTING GUIDE

## CRITICAL FINDING: Agent Core Gateway CLI Commands Don't Exist Yet

Based on official AWS CLI documentation research, **Agent Core Gateway commands are NOT available in aws bedrock-agent or bedrock-agent-runtime**.

## What Commands DON'T WORK (Confirmed Invalid):
❌ `aws bedrock-agent-runtime list-agent-core-gateways`
❌ `aws bedrock-agent create-agent-core-gateway` 
❌ `aws bedrock-agent-runtime create-agent-core-gateway`
❌ `aws bedrock create-agent-core-gateway`

## Available AWS CLI Commands (Verified from Documentation):

### bedrock-agent commands:
- create-agent, get-agent, list-agents
- create-knowledge-base, get-knowledge-base, list-knowledge-bases  
- create-flow, get-flow, list-flows
- create-agent-action-group, get-agent-action-group, list-agent-action-groups
- (NO agent-core-gateway commands)

### bedrock-agent-runtime commands:
- create-invocation, get-invocation-step, list-invocations
- create-session, get-session, list-sessions
- retrieve, retrieve-and-generate
- (NO agent-core-gateway commands)

## VALID TROUBLESHOOTING APPROACHES:

### 1. Check Current CLI Version
```bash
# Check AWS CLI version
aws --version

# Update to latest version
pip install --upgrade awscli
# OR
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install --update
```

### 2. Verify Available Commands
```bash
# List all bedrock-agent commands  
aws bedrock-agent help

# List all bedrock-agent-runtime commands
aws bedrock-agent-runtime help

# Search for any agent-core related commands
aws help | grep -i "agent-core" || echo "No agent-core commands found"
```

### 3. Check Region and Credentials
```bash
# Verify AWS configuration
aws sts get-caller-identity
aws configure list
aws configure get region
```

### 4. Test Basic Bedrock Access
```bash
# Test bedrock-agent access
aws bedrock-agent list-agents --region us-east-1

# Test bedrock-agent-runtime access  
aws bedrock-agent-runtime list-sessions --region us-east-1
```

## CONSOLE-ONLY SOLUTION (Recommended):

Since CLI commands don't exist yet, use **AWS Console exclusively**:

### Step 1: Go to AWS Console
```
https://console.aws.amazon.com/bedrock/home?region=us-east-1#/agent-core/gateways
```

### Step 2: Manual Creation Process
1. **Create Gateway**: Use console wizard
2. **Add Targets**: Use "Add Target" button
3. **Configure MCP Endpoints**: Select "MCP Server" → "Lambda ARN"

### Step 3: Workaround for OAuth Issue
If console forces OAuth client instead of IAM Role:

**Option A: Try Different Browser/Session**
- Clear browser cache
- Try incognito/private mode
- Try different browser

**Option B: Check Prerequisites** 
- Ensure Lambda function exists first
- Verify service role has proper permissions
- Confirm you're in us-east-1 region

**Option C: Contact AWS Support**
- This might be a known console issue
- Request CLI command availability timeline

## ALTERNATIVE VERIFICATION METHODS:

### 1. List Existing Resources
```bash
# Check if gateway exists via Lambda resource-based policies
aws lambda get-policy \
  --function-name a208194-calculator-mcp-server \
  --region us-east-1 \
  2>/dev/null || echo "No policy found"

# Check IAM roles
aws iam list-roles --query 'Roles[?contains(RoleName,`agentcore`)].RoleName' --output text
```

### 2. Test Lambda Functions Directly
```bash
# Test calculator Lambda
aws lambda invoke \
  --function-name a208194-calculator-mcp-server \
  --region us-east-1 \
  --payload '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"add","arguments":{"a":5,"b":3}}}' \
  response.json && cat response.json
```

## RECOMMENDED ACTION PLAN:

### Immediate Steps:
1. ✅ **Use Console Only** - CLI commands don't exist yet
2. ✅ **Create Lambda Function First** - `a208194-ai-calculator-mcp-server`
3. ✅ **Use Console Workarounds** for OAuth issue

### For Console OAuth Issue:
1. **Try different target type first** (REST API) then switch to MCP
2. **Refresh page** if dropdown is empty  
3. **Create in different order** - Gateway first, then targets
4. **Contact AWS Support** if issue persists

### Verification:
1. **Manual Testing**: Use console test functionality
2. **Direct Lambda Testing**: Test Lambda functions independently
3. **Enterprise Client Testing**: Test with actual MCP client

## KEY INSIGHT:
🚨 **Agent Core Gateway is likely a preview/early-access feature with console-only support**

The CLI commands may be added in future AWS CLI releases, but currently **console is the only supported interface**.

## Next Steps:
1. Create AI Calculator Lambda via console: `a208194-ai-calculator-mcp-server`
2. Add MCP target via console (work around OAuth issue)
3. Test functionality end-to-end
4. Monitor AWS CLI releases for future command availability