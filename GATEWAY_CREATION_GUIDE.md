# Agent Core Gateway Manual Creation Guide
# Due to console wizard service role selection issues

## Problem
The Bedrock Agent Core Gateway wizard in the AWS Console has known issues with:
- Service role dropdown not populating
- Existing roles not being selectable
- Role creation failing in the wizard

## Solution Approaches

### Approach 1: CloudFormation Template
Use the provided CloudFormation template to create the service role first:

1. **Deploy CloudFormation Stack**:
   ```bash
   aws cloudformation create-stack \
     --stack-name agentcore-gateway-role \
     --template-body file://agentcore-gateway-cfn.yaml \
     --capabilities CAPABILITY_NAMED_IAM \
     --region us-east-1
   ```

2. **Get the Service Role ARN**:
   ```bash
   aws cloudformation describe-stacks \
     --stack-name agentcore-gateway-role \
     --query 'Stacks[0].Outputs[?OutputKey==`ServiceRoleArn`].OutputValue' \
     --output text
   ```

3. **Use the ARN in console**: Copy the ARN and manually enter it in the gateway wizard

### Approach 2: Console Workarounds

#### Option A: Refresh and Retry
1. Go to AWS Console → IAM → Roles
2. Verify the role `a208194-askjulius-agentcore-gateway` exists
3. Copy its ARN: `arn:aws:iam::818565325759:role/a208194-askjulius-agentcore-gateway`
4. Go to Bedrock → Agent Core → Gateways
5. Refresh the page multiple times
6. Try creating the gateway again

#### Option B: Manual Role ARN Entry
Some versions of the console allow direct ARN entry:
1. In the service role field, try typing the full ARN directly
2. Use: `arn:aws:iam::818565325759:role/a208194-askjulius-agentcore-gateway`

#### Option C: Create New Role in Wizard
If the wizard offers "Create new role":
1. Choose that option
2. Let it auto-create a role
3. Note the created role name for future reference

### Approach 3: AWS CLI (if available)
Try these CLI commands (may vary by AWS CLI version):

```bash
# Method 1
aws bedrock-agent-runtime create-agent-core-gateway \
  --gateway-name "a208194-askjulius-agentcore-gateway" \
  --service-role-arn "arn:aws:iam::818565325759:role/a208194-askjulius-agentcore-gateway" \
  --region us-east-1

# Method 2  
aws bedrock create-agent-core-gateway \
  --gateway-name "a208194-askjulius-agentcore-gateway" \
  --service-role-arn "arn:aws:iam::818565325759:role/a208194-askjulius-agentcore-gateway" \
  --region us-east-1
```

## Gateway Configuration Details

### Required Information:
- **Gateway Name**: `a208194-askjulius-agentcore-gateway`
- **Service Role ARN**: `arn:aws:iam::818565325759:role/a208194-askjulius-agentcore-gateway`
- **Region**: `us-east-1`
- **Semantic Search**: Enabled

### Target Configuration:
- **Target Name**: `a208194-application-details-tool-target`
- **Target Description**: `Details of the application based on the asset insight`
- **Target Type**: Lambda ARN
- **Lambda ARN**: `arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent`
- **Outbound Auth**: IAM Role

### Schema (copy-paste into inline schema field):
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

## Troubleshooting

### If Service Role Dropdown is Empty:
1. Wait 2-3 minutes after role creation
2. Refresh the browser page
3. Clear browser cache
4. Try in incognito/private mode
5. Try different browser

### If Role Still Not Visible:
1. Check role exists in IAM console
2. Verify role has correct trust policy for bedrock.amazonaws.com
3. Ensure you're in the correct AWS region (us-east-1)
4. Try creating a test role with a different name

### Alternative: Support Case
If all methods fail, consider opening an AWS Support case for Bedrock Agent Core Gateway role selection issues.

## Expected Outcome
Once created successfully, you should have:
- Gateway Name: `a208194-askjulius-agentcore-gateway`
- Status: Active
- Target: Connected to Lambda function
- Ready to handle requests with `{"asset_id": "a12345"}` format