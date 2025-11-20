#!/bin/bash
# Quick Cloud Shell Authentication Setup
# This script helps you set up temporary AWS credentials in Cloud Shell

echo "=============================================="
echo "Cloud Shell - AWS Temporary Credentials Setup"
echo "=============================================="
echo ""

# Function to show credential format
show_credential_format() {
    echo "📋 Temporary credentials should look like this:"
    echo ""
    echo "export AWS_ACCESS_KEY_ID=\"ASIA...\""
    echo "export AWS_SECRET_ACCESS_KEY=\"...\""
    echo "export AWS_SESSION_TOKEN=\"...\""
    echo ""
    echo "Note: Temporary Access Key IDs start with 'ASIA'"
    echo "      Permanent Access Key IDs start with 'AKIA'"
    echo ""
}

# Function to validate credentials
validate_credentials() {
    echo "🔍 Validating AWS credentials..."
    
    if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
        echo "❌ AWS_ACCESS_KEY_ID not set"
        return 1
    fi
    
    if [[ -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        echo "❌ AWS_SECRET_ACCESS_KEY not set"
        return 1
    fi
    
    # Check if this looks like temporary credentials
    if [[ "$AWS_ACCESS_KEY_ID" == ASIA* ]]; then
        if [[ -z "${AWS_SESSION_TOKEN:-}" ]]; then
            echo "❌ Temporary credentials detected but AWS_SESSION_TOKEN not set"
            return 1
        fi
        echo "✅ Temporary credentials format looks correct"
    elif [[ "$AWS_ACCESS_KEY_ID" == AKIA* ]]; then
        echo "✅ Permanent credentials format detected"
    else
        echo "⚠️  Unusual Access Key ID format: $AWS_ACCESS_KEY_ID"
    fi
    
    return 0
}

# Function to test AWS access
test_aws_access() {
    echo "🧪 Testing AWS access..."
    
    if ! command -v aws &>/dev/null; then
        echo "⚠️  AWS CLI not found - will be installed during deployment"
        return 0
    fi
    
    if aws sts get-caller-identity &>/dev/null; then
        echo "✅ AWS credentials are working!"
        
        # Show identity info
        echo ""
        echo "📊 Your AWS Identity:"
        aws sts get-caller-identity --output table
        
        return 0
    else
        echo "❌ AWS credentials test failed"
        return 1
    fi
}

# Main execution
main() {
    echo "This script helps you verify your AWS credentials for Cloud Shell deployment."
    echo ""
    
    # Check current credentials
    if [[ -n "${AWS_ACCESS_KEY_ID:-}" ]]; then
        echo "🔑 Found existing AWS credentials:"
        echo "   Access Key: ${AWS_ACCESS_KEY_ID:0:10}..."
        echo "   Secret Key: ${AWS_SECRET_ACCESS_KEY:0:6}..."
        if [[ -n "${AWS_SESSION_TOKEN:-}" ]]; then
            echo "   Session Token: ${AWS_SESSION_TOKEN:0:10}..."
        fi
        echo ""
        
        if validate_credentials && test_aws_access; then
            echo ""
            echo "🎉 Credentials are ready! You can now run:"
            echo "   ./deploy-cloudshell.sh v1.0.0"
            exit 0
        else
            echo ""
            echo "❌ Credential validation failed"
        fi
    else
        echo "❌ No AWS credentials found in environment"
    fi
    
    echo ""
    echo "🔧 To set up credentials, you have several options:"
    echo ""
    echo "Option 1: Manual export (recommended for temporary credentials)"
    show_credential_format
    echo "Then run: source setup-cloudshell-auth.sh"
    echo ""
    echo "Option 2: AWS CLI configure"
    echo "   aws configure"
    echo ""
    echo "Option 3: Use AWS CloudShell's built-in credentials"
    echo "   (if you're already in AWS CloudShell with proper permissions)"
    echo ""
    
    # Offer to set credentials interactively
    read -p "Would you like to set credentials interactively? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        setup_credentials_interactive
    else
        echo "Please set your credentials and run this script again."
    fi
}

# Function for interactive credential setup
setup_credentials_interactive() {
    echo ""
    echo "🔐 Interactive Credential Setup"
    echo "================================"
    echo ""
    
    read -p "AWS Access Key ID: " access_key
    read -s -p "AWS Secret Access Key: " secret_key
    echo ""
    
    # Check if temporary credentials
    if [[ "$access_key" == ASIA* ]]; then
        read -s -p "AWS Session Token: " session_token
        echo ""
        export AWS_SESSION_TOKEN="$session_token"
    fi
    
    export AWS_ACCESS_KEY_ID="$access_key"
    export AWS_SECRET_ACCESS_KEY="$secret_key"
    
    echo ""
    echo "✅ Credentials set for this session"
    echo ""
    
    if validate_credentials && test_aws_access; then
        echo ""
        echo "🎉 Success! Your credentials are working."
        echo ""
        echo "💡 To make these permanent for this session, add them to your ~/.bashrc:"
        echo ""
        echo "echo 'export AWS_ACCESS_KEY_ID=\"$AWS_ACCESS_KEY_ID\"' >> ~/.bashrc"
        echo "echo 'export AWS_SECRET_ACCESS_KEY=\"$AWS_SECRET_ACCESS_KEY\"' >> ~/.bashrc"
        if [[ -n "${AWS_SESSION_TOKEN:-}" ]]; then
            echo "echo 'export AWS_SESSION_TOKEN=\"$AWS_SESSION_TOKEN\"' >> ~/.bashrc"
        fi
        echo ""
        echo "Or create a credentials file to source:"
        cat > aws-credentials.sh << EOF
export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
EOF
        if [[ -n "${AWS_SESSION_TOKEN:-}" ]]; then
            echo "export AWS_SESSION_TOKEN=\"$AWS_SESSION_TOKEN\"" >> aws-credentials.sh
        fi
        echo "✅ Created aws-credentials.sh - run 'source aws-credentials.sh' to load"
        echo ""
        echo "🚀 Ready to deploy! Run:"
        echo "   ./deploy-cloudshell.sh v1.0.0"
    fi
}

# Show help if requested
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    echo "Cloud Shell AWS Authentication Setup"
    echo ""
    echo "This script helps you:"
    echo "  • Validate existing AWS credentials"
    echo "  • Set up new temporary credentials"
    echo "  • Test AWS access before deployment"
    echo ""
    echo "Usage:"
    echo "  ./setup-cloudshell-auth.sh     # Check and setup credentials"
    echo "  ./setup-cloudshell-auth.sh -h  # Show this help"
    echo ""
    echo "For automatic setup:"
    echo "  export AWS_ACCESS_KEY_ID=\"ASIA...\""
    echo "  export AWS_SECRET_ACCESS_KEY=\"...\""
    echo "  export AWS_SESSION_TOKEN=\"...\""
    echo "  ./setup-cloudshell-auth.sh"
    exit 0
fi

main "$@"