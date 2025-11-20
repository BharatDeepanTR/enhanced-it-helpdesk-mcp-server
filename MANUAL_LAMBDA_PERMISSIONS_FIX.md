# 🛠️ Manual AWS Console Fix for Lambda Permissions

## Error: "Access denied while invoking Lambda function"

### The Problem:
The Agent Core Gateway service role doesn't have permission to invoke your Lambda functions.

---

## 🎯 **SOLUTION 1: Fix Service Role Permissions (IAM Console)**

### Step 1: Navigate to IAM Console
1. Go to AWS Console → **IAM** → **Roles**
2. Search for role: `a208194-askjulius-agentcore-gateway`
3. Click on the role name

### Step 2: Update Inline Policy
1. In the role details page, click **"Permissions"** tab
2. Find **"LambdaInvokePolicy"** under **"Inline policies"**
3. Click **"Edit policy"**

### Step 3: Replace Policy JSON
Replace the existing policy with this JSON:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction"
            ],
            "Resource": [
                "arn:aws:lambda:us-east-1:818565325759:function:a208194-calculator-mcp-server",
                "arn:aws:lambda:us-east-1:818565325759:function:a208194-ai-bedrock-calculator-mcp-server",
                "arn:aws:lambda:us-east-1:818565325759:function:a208194-mcp-application-details-server"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction"
            ],
            "Resource": [
                "arn:aws:lambda:us-east-1:818565325759:function:a208194-*"
            ]
        }
    ]
}
```

4. Click **"Review policy"** → **"Save changes"**

---

## 🔐 **SOLUTION 2: Add Lambda Resource-Based Permissions**

You need to add permissions to **each Lambda function** to allow Bedrock to invoke them:

### For Each Lambda Function:

#### Lambda 1: a208194-calculator-mcp-server
1. Go to AWS Console → **Lambda** → **Functions**
2. Click `a208194-calculator-mcp-server`
3. Click **"Configuration"** tab → **"Permissions"** section
4. Scroll down to **"Resource-based policy statements"**
5. Click **"Add permissions"**

**Permission Settings:**
- **Function name**: `a208194-calculator-mcp-server`
- **Statement ID**: `AgentCoreGatewayInvoke`
- **Principal**: `bedrock.amazonaws.com`
- **Action**: `lambda:InvokeFunction`
- **Source ARN** (optional): `arn:aws:bedrock-agentcore:us-east-1:818565325759:gateway/*`

6. Click **"Save"**

#### Lambda 2: a208194-ai-bedrock-calculator-mcp-server
Repeat the same steps:
1. Go to function: `a208194-ai-bedrock-calculator-mcp-server`
2. **Configuration** → **Permissions** → **Add permissions**

**Permission Settings:**
- **Function name**: `a208194-ai-bedrock-calculator-mcp-server`
- **Statement ID**: `AgentCoreGatewayInvoke`
- **Principal**: `bedrock.amazonaws.com`
- **Action**: `lambda:InvokeFunction`
- **Source ARN**: `arn:aws:bedrock-agentcore:us-east-1:818565325759:gateway/*`

#### Lambda 3: a208194-mcp-application-details-server
Repeat for the third function:
1. Go to function: `a208194-mcp-application-details-server`
2. **Configuration** → **Permissions** → **Add permissions**

**Permission Settings:**
- **Function name**: `a208194-mcp-application-details-server`
- **Statement ID**: `AgentCoreGatewayInvoke`
- **Principal**: `bedrock.amazonaws.com`
- **Action**: `lambda:InvokeFunction`
- **Source ARN**: `arn:aws:bedrock-agentcore:us-east-1:818565325759:gateway/*`

---

## 🔍 **VERIFICATION: Check Your Work**

### Verify IAM Role Policy:
1. Go to **IAM** → **Roles** → `a208194-askjulius-agentcore-gateway`
2. **Permissions** tab → **LambdaInvokePolicy** → **Edit**
3. Verify JSON contains all 3 Lambda function ARNs

### Verify Lambda Permissions:
For each Lambda function:
1. **Lambda Console** → **Function** → **Configuration** → **Permissions**
2. Under **Resource-based policy statements**, you should see:
   - **Statement ID**: `AgentCoreGatewayInvoke`
   - **Principal**: `bedrock.amazonaws.com`
   - **Action**: `lambda:InvokeFunction`

---

## ⚡ **Quick Alternative: Policy Generator Method**

If you prefer using AWS Policy Generator:

### For IAM Role Policy:
1. Go to: https://awspolicygen.s3.amazonaws.com/policygen.html
2. **Select Policy Type**: IAM Policy
3. **Effect**: Allow
4. **AWS Service**: Amazon Lambda
5. **Actions**: InvokeFunction
6. **Amazon Resource Name (ARN)**: 
   ```
   arn:aws:lambda:us-east-1:818565325759:function:a208194-calculator-mcp-server
   arn:aws:lambda:us-east-1:818565325759:function:a208194-ai-bedrock-calculator-mcp-server
   arn:aws:lambda:us-east-1:818565325759:function:a208194-mcp-application-details-server
   arn:aws:lambda:us-east-1:818565325759:function:a208194-*
   ```
7. Click **Add Statement** → **Generate Policy**
8. Copy the generated JSON to your IAM role

---

## 🎯 **Expected Result After Fix:**

✅ **Before Fix**: "Access denied while invoking Lambda function"  
✅ **After Fix**: Gateway successfully invokes Lambda functions  
✅ **Test Result**: MCP target responds with proper calculations

---

## ⏰ **Important Notes:**

1. **Wait 1-2 minutes** after making changes for IAM propagation
2. **Both fixes are required**: IAM role policy AND Lambda resource-based policy
3. **Test after each step** to verify the fix works
4. **Source ARN restriction** provides additional security

---

## 🧪 **Test Your Fix:**

After making both changes, test with your enterprise MCP client. The error should change from:
```
❌ "Access denied while invoking Lambda function"
```
To:
```
✅ Successful MCP response or proper error handling
```

This manual approach achieves exactly the same result as the automated script!