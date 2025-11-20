# CloudShell Agent Core Gateway Creation Guide

## 📋 What You Need to Do

### Step 1: Upload Script to AWS CloudShell
1. **Open AWS Console** → **CloudShell** (icon in top toolbar)
2. **Upload the script file**: `cloudshell-agentcore-gateway.sh`
   - Click the "Upload" button in CloudShell
   - Select the `cloudshell-agentcore-gateway.sh` file
   - Wait for upload to complete

### Step 2: Execute in CloudShell
```bash
# Make script executable
chmod +x cloudshell-agentcore-gateway.sh

# Run the script
./cloudshell-agentcore-gateway.sh
```

## 🎯 What the Script Does

1. **Environment Detection**: Verifies you're in CloudShell
2. **Credential Check**: Tests AWS access (automatic in CloudShell)
3. **CLI Version Check**: Verifies AWS CLI version and command availability
4. **Command Execution**: Runs the Agent Core Gateway creation command:
   ```bash
   aws bedrock-agentcore-control create-gateway \
     --name a208194-askjulius-agentcore-gateway \
     --role-arn arn:aws:iam::818565325759:role/a208194-askjulius-agentcore-gateway \
     --protocol-type MCP \
     --authorizer-type AWS_IAM \
     --region us-east-1
   ```

## 🔧 Expected Outcomes

### ✅ Success Case:
- Script detects CloudShell environment
- AWS credentials work automatically
- `bedrock-agentcore-control` command is available
- Gateway is created successfully
- You can verify in AWS Console → Bedrock → Agent Core → Gateways

### ⚠️ If CLI Command Not Available:
- Script will attempt to update AWS CLI
- If still not available, provides manual console instructions
- Shows alternative CLI commands to try

### ❌ If Issues Occur:
- Script provides troubleshooting steps
- Shows debug commands to run
- Explains common permission issues

## 📁 Files Created for CloudShell

1. **`cloudshell-agentcore-gateway.sh`** - Main execution script
2. **`create-gateway-cloudshell.sh`** - Alternative version with credential setup
3. **This README** - Instructions for CloudShell usage

## 🚀 Quick CloudShell Commands

After uploading, just run:
```bash
chmod +x cloudshell-agentcore-gateway.sh
./cloudshell-agentcore-gateway.sh
```

## 💡 Why CloudShell?

- **Automatic AWS Credentials**: No need to configure access keys
- **Latest AWS CLI**: CloudShell typically has newer CLI versions
- **Proper Environment**: Designed for AWS operations
- **No Local Setup**: No need to install/configure anything locally

## 🔍 Verification Steps

After the script runs successfully:

1. **Check AWS Console**:
   - Go to Bedrock → Agent Core → Gateways
   - Look for: `a208194-askjulius-agentcore-gateway`
   - Status should be "Active"

2. **CLI Verification**:
   ```bash
   aws bedrock-agentcore-control list-gateways --region us-east-1
   ```

3. **Get Gateway Details**:
   ```bash
   aws bedrock-agentcore-control get-gateway --gateway-id <gateway-id> --region us-east-1
   ```

## 🎉 Success!

Once the gateway is created, you'll have:
- **Gateway Name**: `a208194-askjulius-agentcore-gateway`
- **Protocol**: MCP (Model Context Protocol)
- **Authorization**: AWS IAM
- **Ready for**: Target configuration and endpoint setup

The service role visibility issue is bypassed completely when using CLI commands!