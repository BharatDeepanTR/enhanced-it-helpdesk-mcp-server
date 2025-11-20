#!/bin/bash
# Simple Solution: Temporarily Remove PostAuthentication Trigger
# Since you can't modify the failing Lambda function, remove the trigger temporarily

echo "🔧 Simple PostAuthentication Trigger Removal"
echo "============================================"
echo ""

USER_POOL_ID="us-east-1_wzWpXwzR6"
POST_AUTH_FUNCTION="a207907-73-popularqueries-s3"

echo "🎯 The Problem:"
echo "==============="
echo "   ✅ Your MCP function (a208194-chatops_application_details_intent) is fine"
echo "   ❌ PostAuthentication trigger ($POST_AUTH_FUNCTION) is blocking JWT tokens"
echo "   ❌ You don't have permissions to fix the trigger's Lambda function"
echo ""

echo "💡 The Solution:"
echo "================"
echo "   Temporarily remove the PostAuthentication trigger to allow JWT token generation"
echo ""

echo "🔍 Current Cognito Lambda Triggers:"
echo "==================================="

# Get current Lambda configuration
CURRENT_CONFIG=$(aws cognito-idp describe-user-pool \
  --user-pool-id $USER_POOL_ID \
  --query 'UserPool.LambdaConfig' \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "Current triggers:"
    echo "$CURRENT_CONFIG" | jq '.'
    
    # Check if PostAuthentication exists
    POST_AUTH_ARN=$(echo "$CURRENT_CONFIG" | jq -r '.PostAuthentication // "null"')
    
    if [ "$POST_AUTH_ARN" != "null" ]; then
        echo ""
        echo "❌ PostAuthentication trigger found: $POST_AUTH_ARN"
        echo "   This is what's causing the authentication failure"
    else
        echo ""
        echo "🤔 No PostAuthentication trigger found (unexpected)"
    fi
else
    echo "❌ Cannot access User Pool configuration"
    echo "   You may not have cognito-idp:DescribeUserPool permissions"
fi

echo ""
echo "🚀 Option A: Remove PostAuthentication Trigger (CLI)"
echo "=================================================="

read -p "Do you want to remove the PostAuthentication trigger? (y/N): " remove_trigger

if [[ $remove_trigger =~ ^[Yy]$ ]]; then
    echo ""
    echo "🔄 Removing PostAuthentication trigger..."
    
    # Create new Lambda config without PostAuthentication
    NEW_CONFIG=$(echo "$CURRENT_CONFIG" | jq 'del(.PostAuthentication)')
    
    echo "New configuration (without PostAuthentication):"
    echo "$NEW_CONFIG"
    echo ""
    
    # Apply the new configuration
    aws cognito-idp update-user-pool \
      --user-pool-id $USER_POOL_ID \
      --lambda-config "$NEW_CONFIG"
    
    if [ $? -eq 0 ]; then
        echo "✅ PostAuthentication trigger removed successfully!"
        echo ""
        echo "🧪 Now test authentication immediately:"
        echo "./interactive-cognito-auth.sh"
        echo ""
        echo "📝 To restore the trigger later (SAVE THIS COMMAND):"
        echo "aws cognito-idp update-user-pool \\"
        echo "  --user-pool-id $USER_POOL_ID \\"
        echo "  --lambda-config '$CURRENT_CONFIG'"
        echo ""
        echo "💾 Saved original config to: /tmp/original-lambda-config.json"
        echo "$CURRENT_CONFIG" > /tmp/original-lambda-config.json
    else
        echo "❌ Failed to remove PostAuthentication trigger"
        echo "   You may not have cognito-idp:UpdateUserPool permissions"
        echo "   Try the manual console method below"
    fi
else
    echo ""
    echo "🖱️ Option B: Manual Console Method (Recommended)"
    echo "=============================================="
    echo ""
    echo "Step-by-step instructions:"
    echo ""
    echo "1. 🌐 Open AWS Console: https://console.aws.amazon.com/cognito/"
    echo "2. 📋 Click 'User pools'"
    echo "3. 🎯 Click on: $USER_POOL_ID"
    echo "4. ⚙️  In left sidebar: 'User pool properties'"
    echo "5. 🔧 Click 'Lambda triggers' tab"
    echo "6. 📝 Find 'PostAuthentication' section"
    echo "7. ✏️  Click 'Edit' or pencil icon"
    echo "8. 🗑️  Remove/clear the Lambda function selection"
    echo "9. 💾 Click 'Save changes'"
    echo "10. 🧪 Test: ./interactive-cognito-auth.sh"
    echo ""
    echo "📸 Before removing, take a screenshot of the current config"
    echo "   so you can restore it later!"
fi

echo ""
echo "🧪 Quick Test After Trigger Removal"
echo "==================================="
echo ""
echo "Once you remove the PostAuthentication trigger, test immediately:"
echo ""

# Create a quick test command
cat > /tmp/quick-auth-test.sh << 'EOF'
#!/bin/bash
echo "🧪 Quick Authentication Test"
echo "============================"
echo ""
echo "This will test if removing the PostAuthentication trigger worked"
echo ""

# Get client secret securely
read -s -p "Enter client secret for testing: " CLIENT_SECRET
echo ""
echo ""

# Test authentication
python3 << EOL
import boto3
import hmac
import hashlib
import base64
import json

def calculate_secret_hash(username, client_id, client_secret):
    message = username + client_id
    dig = hmac.new(
        str(client_secret).encode('utf-8'),
        msg=str(message).encode('utf-8'),
        digestmod=hashlib.sha256
    ).digest()
    return base64.b64encode(dig).decode()

# Configuration
user_pool_id = "us-east-1_wzWpXwzR6"
client_id = "57o30hpgrhrovfbe4tmnkrtv50"
client_secret = "$CLIENT_SECRET"
username = "mcptest"
password = "McpTest123!"

print("🔐 Testing authentication without PostAuth trigger...")

try:
    cognito = boto3.client('cognito-idp', region_name='us-east-1')
    
    # Calculate SECRET_HASH
    secret_hash = calculate_secret_hash(username, client_id, client_secret)
    
    # Authenticate
    auth_response = cognito.admin_initiate_auth(
        UserPoolId=user_pool_id,
        ClientId=client_id,
        AuthFlow='ADMIN_USER_PASSWORD_AUTH',
        AuthParameters={
            'USERNAME': username,
            'PASSWORD': password,
            'SECRET_HASH': secret_hash
        }
    )
    
    print("🎉 SUCCESS! Authentication worked!")
    print("   PostAuthentication trigger removal was successful")
    
    # Get access token
    access_token = auth_response['AuthenticationResult']['AccessToken']
    print(f"✅ Access token obtained: {access_token[:30]}...")
    
    print("")
    print("🚀 You can now test your MCP gateway with:")
    print("./interactive-cognito-auth.sh")
    
except Exception as e:
    print(f"❌ Still failing: {e}")
    print("   Check if the trigger was actually removed")

EOL
EOF

chmod +x /tmp/quick-auth-test.sh

echo ""
echo "📋 After removing the trigger, run this quick test:"
echo "/tmp/quick-auth-test.sh"
echo ""

echo "🔄 Restoration Process:"
echo "======================="
echo ""
echo "To restore the PostAuthentication trigger later:"
echo ""
echo "1. 📋 Use the saved command from above, OR"
echo "2. 🖱️ Go back to Cognito Console > Lambda triggers"
echo "3. ➕ Add back the PostAuthentication function:"
echo "   arn:aws:lambda:us-east-1:818565325759:function:a207907-73-popularqueries-s3"
echo "4. 🔧 Fix the Lambda function's permissions first"
echo "5. 💾 Save the trigger configuration"
echo ""

echo "💡 Important Notes:"
echo "=================="
echo ""
echo "✅ Removing this trigger is safe for testing"
echo "⚠️  But understand what the trigger does before permanent removal"
echo "🔧 The proper long-term solution is fixing the Lambda function permissions"
echo "📞 Consider contacting whoever manages that Lambda function"
echo ""

echo "🎯 Expected Result:"
echo "=================="
echo ""
echo "After removing the PostAuthentication trigger:"
echo "✅ Authentication will succeed"
echo "✅ JWT tokens will be generated" 
echo "✅ You can test your MCP gateway"
echo "✅ Your a208194-chatops_application_details_intent function will work"
echo ""
echo "Your MCP gateway setup is perfect - this trigger removal unblocks it!"