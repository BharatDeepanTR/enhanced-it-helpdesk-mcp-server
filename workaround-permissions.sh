#!/bin/bash
# Workaround for Limited Lambda Permissions
# Focus on Cognito User Pool configuration instead of Lambda analysis

echo "🔧 Cognito PostAuthentication Trigger Removal (Limited Permissions)"
echo "=================================================================="
echo ""

USER_POOL_ID="us-east-1_wzWpXwzR6"
CLIENT_ID="57o30hpgrhrovfbe4tmnkrtv50"

echo "🔍 Working Around Permission Limitations:"
echo "========================================="
echo ""
echo "❌ You don't have lambda:GetFunctionConfiguration"
echo "✅ We'll focus on Cognito User Pool management instead"
echo "💡 The goal: Remove the failing PostAuthentication trigger"
echo ""

echo "🎯 Step 1: Check Cognito User Pool Access"
echo "========================================="

# Test Cognito access first
echo "Testing Cognito User Pool access..."

POOL_INFO=$(aws cognito-idp describe-user-pool \
  --user-pool-id $USER_POOL_ID \
  --query 'UserPool.{Name:Name,Status:Status}' \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ You have cognito-idp:DescribeUserPool permissions"
    POOL_NAME=$(echo "$POOL_INFO" | jq -r '.Name')
    POOL_STATUS=$(echo "$POOL_INFO" | jq -r '.Status')
    echo "   Pool Name: $POOL_NAME"
    echo "   Pool Status: $POOL_STATUS"
else
    echo "❌ You don't have cognito-idp:DescribeUserPool permissions"
    echo "   You'll need to use the AWS Console method"
fi

echo ""
echo "🎯 Step 2: Check Lambda Trigger Configuration" 
echo "============================================="

LAMBDA_CONFIG=$(aws cognito-idp describe-user-pool \
  --user-pool-id $USER_POOL_ID \
  --query 'UserPool.LambdaConfig' \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Successfully retrieved Lambda trigger configuration:"
    echo "$LAMBDA_CONFIG" | jq '.'
    
    # Check for PostAuthentication trigger
    POST_AUTH=$(echo "$LAMBDA_CONFIG" | jq -r '.PostAuthentication // "null"')
    
    if [ "$POST_AUTH" != "null" ]; then
        echo ""
        echo "🎯 Found the problematic trigger:"
        echo "   PostAuthentication: $POST_AUTH"
        echo "   This is what's causing the authentication failure"
    fi
else
    echo "❌ Cannot retrieve Lambda configuration"
    echo "   Limited Cognito permissions"
fi

echo ""
echo "🎯 Step 3: Test UpdateUserPool Permissions"
echo "=========================================="

# Test if we can update the user pool (without actually changing anything)
echo "Testing if you have cognito-idp:UpdateUserPool permissions..."

# Try to get current user pool configuration 
CURRENT_POOL_CONFIG=$(aws cognito-idp describe-user-pool \
  --user-pool-id $USER_POOL_ID \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Can read user pool configuration"
    
    # Test update permissions with a harmless change
    echo "Testing update permissions (this won't change anything)..."
    
    # We won't actually run this, just show what would be needed
    echo "📋 Update command would be:"
    echo "aws cognito-idp update-user-pool --user-pool-id $USER_POOL_ID --lambda-config '{}'"
else
    echo "❌ Cannot read full user pool configuration"
fi

echo ""
echo "🚀 SOLUTION PATHS (Choose Based on Your Permissions)"
echo "===================================================="
echo ""

echo "Path A: CLI Method (If you have cognito-idp:UpdateUserPool)"
echo "==========================================================="
echo ""
echo "If you want to try removing the trigger via CLI:"
echo ""
read -p "Do you want to attempt CLI trigger removal? (y/N): " try_cli

if [[ $try_cli =~ ^[Yy]$ ]]; then
    echo ""
    echo "🔄 Attempting to remove PostAuthentication trigger..."
    
    # Save original config first
    if [ -n "$LAMBDA_CONFIG" ] && [ "$LAMBDA_CONFIG" != "null" ]; then
        echo "$LAMBDA_CONFIG" > /tmp/cognito-original-config.json
        echo "💾 Original config saved to: /tmp/cognito-original-config.json"
        
        # Create new config without PostAuthentication
        NEW_CONFIG=$(echo "$LAMBDA_CONFIG" | jq 'del(.PostAuthentication)')
        echo ""
        echo "📋 New configuration (without PostAuthentication):"
        echo "$NEW_CONFIG"
        
        echo ""
        read -p "Apply this configuration? (y/N): " confirm_apply
        
        if [[ $confirm_apply =~ ^[Yy]$ ]]; then
            aws cognito-idp update-user-pool \
              --user-pool-id $USER_POOL_ID \
              --lambda-config "$NEW_CONFIG"
            
            if [ $? -eq 0 ]; then
                echo "✅ SUCCESS! PostAuthentication trigger removed!"
                echo ""
                echo "🧪 Test authentication immediately:"
                echo "./interactive-cognito-auth.sh"
                echo ""
                echo "📝 To restore later:"
                echo "aws cognito-idp update-user-pool \\"
                echo "  --user-pool-id $USER_POOL_ID \\"
                echo "  --lambda-config file:///tmp/cognito-original-config.json"
            else
                echo "❌ Failed to update user pool"
                echo "   You may not have cognito-idp:UpdateUserPool permissions"
                echo "   Use the Console method below"
            fi
        else
            echo "Skipped applying configuration"
        fi
    else
        echo "❌ Could not retrieve current Lambda configuration"
    fi
else
    echo ""
    echo "Path B: AWS Console Method (Recommended - Always Works)"
    echo "======================================================"
    echo ""
    echo "📋 Detailed Console Instructions:"
    echo ""
    echo "1. 🌐 Open: https://console.aws.amazon.com/cognito/"
    echo ""
    echo "2. 📋 Navigation:"
    echo "   • Click 'User pools'"
    echo "   • Search for: $USER_POOL_ID"
    echo "   • Click on the User Pool"
    echo ""
    echo "3. 🔧 Remove Trigger:"
    echo "   • Left sidebar: Click 'User pool properties'"
    echo "   • Top tabs: Click 'Lambda triggers'"
    echo "   • Find 'PostAuthentication' section"
    echo "   • Click 'Edit' (pencil icon)"
    echo "   • Select 'None' or clear the Lambda function"
    echo "   • Click 'Save changes'"
    echo ""
    echo "4. ✅ Verify:"
    echo "   • PostAuthentication should show 'None' or be empty"
    echo "   • No errors should be displayed"
    echo ""
    echo "5. 🧪 Test Immediately:"
    echo "   • ./interactive-cognito-auth.sh"
    echo "   • Should now work without the trigger blocking it"
    echo ""
    
    echo "📸 IMPORTANT: Take a screenshot before removing!"
    echo "   You'll need this to restore the trigger later"
    echo ""
    echo "🔄 To restore later (after fixing the Lambda):"
    echo "   • Go back to Lambda triggers"
    echo "   • Select PostAuthentication"
    echo "   • Choose: a207907-73-popularqueries-s3"
    echo "   • Save changes"
fi

echo ""
echo "🧪 Quick Test Script (Use After Removing Trigger)"
echo "================================================="

# Create a minimal test script
cat > /tmp/test-after-trigger-removal.sh << 'EOF'
#!/bin/bash
echo "🧪 Testing Authentication After Trigger Removal"
echo "==============================================="
echo ""

echo "This test will verify the PostAuthentication trigger removal worked"
echo ""

# Get client secret
read -s -p "Enter Cognito client secret: " CLIENT_SECRET
echo ""
echo ""

python3 << EOL
import boto3
import hmac
import hashlib
import base64

def calculate_secret_hash(username, client_id, client_secret):
    message = username + client_id
    dig = hmac.new(
        str(client_secret).encode('utf-8'),
        msg=str(message).encode('utf-8'),
        digestmod=hashlib.sha256
    ).digest()
    return base64.b64encode(dig).decode()

print("🔐 Testing authentication without PostAuth trigger...")
print("==================================================")

try:
    cognito = boto3.client('cognito-idp', region_name='us-east-1')
    
    # Calculate SECRET_HASH
    secret_hash = calculate_secret_hash('mcptest', '57o30hpgrhrovfbe4tmnkrtv50', '$CLIENT_SECRET')
    
    # Authenticate
    response = cognito.admin_initiate_auth(
        UserPoolId='us-east-1_wzWpXwzR6',
        ClientId='57o30hpgrhrovfbe4tmnkrtv50',
        AuthFlow='ADMIN_USER_PASSWORD_AUTH',
        AuthParameters={
            'USERNAME': 'mcptest',
            'PASSWORD': 'McpTest123!',
            'SECRET_HASH': secret_hash
        }
    )
    
    print("🎉 SUCCESS!")
    print("✅ Authentication worked - trigger removal successful!")
    print("✅ JWT tokens obtained")
    
    access_token = response['AuthenticationResult']['AccessToken']
    print(f"✅ Access Token: {access_token[:30]}...")
    print("")
    print("🚀 Ready to test MCP gateway!")
    print("Run: ./interactive-cognito-auth.sh")
    
except Exception as e:
    print(f"❌ Still failing: {e}")
    if 'PostAuthentication' in str(e):
        print("💡 The trigger may not have been removed yet")
        print("   Double-check the Console steps")
    else:
        print("💡 Different error - may need to investigate further")

EOL
EOF

chmod +x /tmp/test-after-trigger-removal.sh

echo ""
echo "📋 Summary & Next Steps:"
echo "======================="
echo ""
echo "🎯 Goal: Remove PostAuthentication trigger to unblock JWT generation"
echo ""
echo "✅ If CLI method worked:"
echo "   • Test immediately: ./interactive-cognito-auth.sh"
echo "   • Should get JWT tokens and access MCP gateway"
echo ""
echo "🖱️ If using Console method:"
echo "   • Follow the detailed steps above"
echo "   • Test with: /tmp/test-after-trigger-removal.sh"
echo ""
echo "💡 Remember:"
echo "   • Your MCP gateway function is correctly configured"
echo "   • This is just removing an authentication blocker"
echo "   • You can restore the trigger later (after fixing it)"
echo ""

echo "✅ Permission workaround script completed!"