#!/bin/bash
# Diagnose Cognito Authentication Issues
# Help identify why authentication is failing

echo "🔍 Cognito Authentication Diagnostics"
echo "====================================="
echo ""

USER_POOL_ID="us-east-1_wzWpXwzR6"
CLIENT_ID="57o30hpgrhrovfbe4tmnkrtv50"
USERNAME="bharatdeepan.vairavakkalai@thomsonreuters.com"

echo "📋 Configuration:"
echo "  User Pool: $USER_POOL_ID"
echo "  Client ID: $CLIENT_ID"
echo "  Username: $USERNAME"
echo ""

echo "🔍 Step 1: Check User Existence and Status"
echo "=========================================="

echo "Checking if user exists in the user pool..."

USER_INFO=$(aws cognito-idp admin-get-user \
  --user-pool-id $USER_POOL_ID \
  --username "$USERNAME" \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ User found in user pool!"
    echo ""
    
    # Extract user status
    USER_STATUS=$(echo "$USER_INFO" | jq -r '.UserStatus')
    ENABLED=$(echo "$USER_INFO" | jq -r '.Enabled')
    
    echo "📋 User Details:"
    echo "  Status: $USER_STATUS"
    echo "  Enabled: $ENABLED"
    echo ""
    
    # Show user attributes
    echo "📋 User Attributes:"
    echo "$USER_INFO" | jq '.UserAttributes[] | "  \(.Name): \(.Value)"' -r
    echo ""
    
    # Check critical status
    if [ "$USER_STATUS" = "CONFIRMED" ]; then
        echo "✅ User is CONFIRMED - good for authentication"
    elif [ "$USER_STATUS" = "UNCONFIRMED" ]; then
        echo "❌ User is UNCONFIRMED - needs email/phone confirmation"
        echo "💡 This could be why authentication is failing"
    elif [ "$USER_STATUS" = "FORCE_CHANGE_PASSWORD" ]; then
        echo "⚠️  User needs to change password first"
        echo "💡 Try password reset or admin password change"
    else
        echo "⚠️  User status: $USER_STATUS"
        echo "💡 Unusual status - may need admin intervention"
    fi
    
    if [ "$ENABLED" = "false" ]; then
        echo "❌ User account is DISABLED"
        echo "💡 Admin needs to enable the account"
    fi
    
else
    echo "❌ User NOT FOUND in user pool!"
    echo "💡 Possible issues:"
    echo "   1. Username case sensitivity"
    echo "   2. User in different user pool"
    echo "   3. User hasn't been created yet"
    echo ""
    echo "🔍 Let's check with different case variations..."
    
    # Try lowercase
    LOWER_USERNAME=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]')
    if [ "$LOWER_USERNAME" != "$USERNAME" ]; then
        echo "   Trying lowercase: $LOWER_USERNAME"
        aws cognito-idp admin-get-user \
          --user-pool-id $USER_POOL_ID \
          --username "$LOWER_USERNAME" \
          --query 'UserStatus' \
          --output text 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "   ✅ Found user with lowercase!"
            USERNAME="$LOWER_USERNAME"
        fi
    fi
fi

echo ""
echo "🔍 Step 2: Check User Pool Client Configuration"
echo "=============================================="

CLIENT_INFO=$(aws cognito-idp describe-user-pool-client \
  --user-pool-id $USER_POOL_ID \
  --client-id $CLIENT_ID \
  --output json 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Client configuration retrieved"
    echo ""
    
    # Check auth flows
    AUTH_FLOWS=$(echo "$CLIENT_INFO" | jq -r '.UserPoolClient.ExplicitAuthFlows[]?' 2>/dev/null)
    echo "📋 Enabled Auth Flows:"
    echo "$AUTH_FLOWS" | sed 's/^/  • /'
    
    if echo "$AUTH_FLOWS" | grep -q "ADMIN_USER_PASSWORD_AUTH"; then
        echo "✅ ADMIN_USER_PASSWORD_AUTH is enabled"
    else
        echo "❌ ADMIN_USER_PASSWORD_AUTH is NOT enabled"
        echo "💡 This could be why authentication is failing"
    fi
    
    # Check if client secret is required
    CLIENT_SECRET_REQ=$(echo "$CLIENT_INFO" | jq -r '.UserPoolClient.GenerateSecret')
    echo ""
    echo "📋 Client Secret Required: $CLIENT_SECRET_REQ"
    
    if [ "$CLIENT_SECRET_REQ" = "true" ]; then
        echo "✅ Client secret is required (matches our usage)"
    else
        echo "⚠️  Client secret not required - may be causing issues"
    fi
    
else
    echo "❌ Cannot retrieve client configuration"
    echo "💡 May not have permissions or client doesn't exist"
fi

echo ""
echo "🔍 Step 3: Test Different Username Formats"
echo "========================================"

echo "Let's test authentication with different username formats..."
echo ""

# Get credentials
read -s -p "Enter Cognito client secret: " CLIENT_SECRET
echo ""
read -s -p "Enter password: " USER_PASSWORD  
echo ""
echo ""

# Test function
test_auth() {
    local test_username="$1"
    local label="$2"
    
    echo "🧪 Testing: $label ($test_username)"
    
    python3 << EOF
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

try:
    cognito = boto3.client('cognito-idp', region_name='us-east-1')
    
    username = '$test_username'
    client_id = '$CLIENT_ID'
    client_secret = '$CLIENT_SECRET'
    password = '$USER_PASSWORD'
    user_pool_id = '$USER_POOL_ID'
    
    secret_hash = calculate_secret_hash(username, client_id, client_secret)
    
    response = cognito.admin_initiate_auth(
        UserPoolId=user_pool_id,
        ClientId=client_id,
        AuthFlow='ADMIN_USER_PASSWORD_AUTH',
        AuthParameters={
            'USERNAME': username,
            'PASSWORD': password,
            'SECRET_HASH': secret_hash
        }
    )
    
    print("   ✅ SUCCESS! Authentication worked!")
    print(f"   Access token: {response['AuthenticationResult']['AccessToken'][:30]}...")
    
    # Save successful username for later
    with open('/tmp/working-username.txt', 'w') as f:
        f.write(username)
    
    exit(0)
    
except Exception as e:
    error_str = str(e)
    if 'NotAuthorizedException' in error_str and 'Incorrect username or password' in error_str:
        print("   ❌ Incorrect username or password")
    elif 'UserNotConfirmedException' in error_str:
        print("   ❌ User not confirmed") 
    elif 'InvalidParameterException' in error_str:
        print("   ❌ Invalid parameters (possibly SECRET_HASH issue)")
    elif 'NotAuthorizedException' in error_str and 'Password attempts exceeded' in error_str:
        print("   ❌ Too many failed attempts - account temporarily locked")
    else:
        print(f"   ❌ Other error: {error_str[:100]}")

EOF
}

# Test original username
test_auth "$USERNAME" "Original email"

# Test lowercase
LOWER_USERNAME=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]')
if [ "$LOWER_USERNAME" != "$USERNAME" ]; then
    test_auth "$LOWER_USERNAME" "Lowercase email"
fi

# Test without domain
USERNAME_ONLY=$(echo "$USERNAME" | cut -d'@' -f1)
test_auth "$USERNAME_ONLY" "Username part only"

# Test if a working username was found
if [ -f "/tmp/working-username.txt" ]; then
    WORKING_USERNAME=$(cat /tmp/working-username.txt)
    echo ""
    echo "🎉 FOUND WORKING USERNAME: $WORKING_USERNAME"
    echo ""
    echo "💡 Use this username for future authentication:"
    echo "   Update your scripts to use: $WORKING_USERNAME"
    rm -f /tmp/working-username.txt
else
    echo ""
    echo "❌ No username format worked"
    echo ""
    echo "🔧 Troubleshooting Steps:"
    echo "========================"
    echo ""
    echo "1. 📧 Verify Email Address:"
    echo "   • Check exact spelling in Cognito console"
    echo "   • Look for typos or extra characters"
    echo "   • Case sensitivity matters"
    echo ""
    echo "2. 🔑 Password Issues:"
    echo "   • Try resetting password"
    echo "   • Check if temporary password needs to be changed"
    echo "   • Verify password complexity requirements"
    echo ""
    echo "3. 👤 User Status Issues:"
    if [ -n "$USER_STATUS" ] && [ "$USER_STATUS" != "CONFIRMED" ]; then
        echo "   • User status is: $USER_STATUS"
        echo "   • Confirm email/phone if UNCONFIRMED"
        echo "   • Admin may need to force confirm user"
    else
        echo "   • Check user status in Cognito console"
        echo "   • User may need email confirmation"
    fi
    echo ""
    echo "4. 🔧 Admin Actions Needed:"
    echo "   aws cognito-idp admin-confirm-sign-up \\"
    echo "     --user-pool-id $USER_POOL_ID \\"
    echo "     --username '$USERNAME'"
    echo ""
    echo "   aws cognito-idp admin-set-user-password \\"
    echo "     --user-pool-id $USER_POOL_ID \\"
    echo "     --username '$USERNAME' \\"
    echo "     --password 'NewPassword123!' \\"
    echo "     --permanent"
fi

echo ""
echo "✅ Authentication diagnostics completed!"