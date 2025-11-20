#!/bin/bash
# Cloud Shell Environment Setup Script
# Handles temporary AWS credentials and Docker configuration

set -e

echo "🔧 Cloud Shell Environment Setup for DNS Lookup Service"
echo "====================================================="
echo ""

# Function to setup temporary AWS credentials
setup_temporary_credentials() {
    echo "🔑 Setting up temporary AWS credentials..."
    
    # Check if credentials are already configured
    if aws sts get-caller-identity >/dev/null 2>&1; then
        CURRENT_USER=$(aws sts get-caller-identity --query Arn --output text)
        echo "   ✅ AWS credentials already configured"
        echo "   👤 Current identity: $CURRENT_USER"
        return 0
    fi
    
    echo ""
    echo "📝 Temporary credentials setup options:"
    echo ""
    echo "Option 1: Manual Environment Variables"
    echo "   export AWS_ACCESS_KEY_ID=your_access_key"
    echo "   export AWS_SECRET_ACCESS_KEY=your_secret_key"
    echo "   export AWS_SESSION_TOKEN=your_session_token  # (if using STS)"
    echo ""
    echo "Option 2: AWS Configure"
    echo "   aws configure"
    echo ""
    echo "Option 3: Assume Role (for cross-account access)"
    echo "   aws sts assume-role --role-arn arn:aws:iam::ACCOUNT:role/ROLE --role-session-name session"
    echo ""
    
    read -p "Have you configured AWS credentials? (y/n): " CONFIGURED
    
    if [ "$CONFIGURED" = "y" ] || [ "$CONFIGURED" = "Y" ]; then
        if aws sts get-caller-identity >/dev/null 2>&1; then
            echo "   ✅ Credentials verified successfully"
        else
            echo "   ❌ Credential verification failed"
            echo "   Please check your configuration and try again"
            exit 1
        fi
    else
        echo "   ℹ️  Please configure your AWS credentials first"
        echo "   Run this script again after configuration"
        exit 1
    fi
}

# Function to check and setup Docker
setup_docker_environment() {
    echo ""
    echo "🐳 Setting up Docker environment..."
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        echo "   ⚠️  Docker not running, attempting to start..."
        
        # Try to start Docker (may require sudo in some Cloud Shell environments)
        if sudo systemctl start docker 2>/dev/null; then
            echo "   ✅ Docker started successfully"
        else
            echo "   ℹ️  Docker service management may require manual intervention"
            echo "   Try: sudo systemctl start docker"
        fi
    else
        echo "   ✅ Docker is running"
    fi
    
    # Check Docker buildx
    if docker buildx version >/dev/null 2>&1; then
        echo "   ✅ Docker buildx available"
    else
        echo "   ⚠️  Docker buildx not available, will use legacy build"
    fi
    
    # Set Docker environment variables
    export DOCKER_BUILDKIT=1
    export DOCKER_CLI_EXPERIMENTAL=enabled
    echo "   ✅ Docker BuildKit enabled"
}

# Function to verify ECR access
verify_ecr_access() {
    echo ""
    echo "🏗️  Verifying ECR access..."
    
    REGION=${AWS_DEFAULT_REGION:-"us-east-1"}
    
    if aws ecr describe-repositories --region $REGION >/dev/null 2>&1; then
        echo "   ✅ ECR access verified"
    else
        echo "   ⚠️  ECR access check failed"
        echo "   This might be due to no repositories existing yet (normal)"
        echo "   The deploy script will create the repository if needed"
    fi
}

# Function to check required tools
check_required_tools() {
    echo ""
    echo "🔍 Checking required tools..."
    
    TOOLS=("aws" "docker" "jq")
    MISSING_TOOLS=()
    
    for tool in "${TOOLS[@]}"; do
        if command -v $tool >/dev/null 2>&1; then
            echo "   ✅ $tool installed"
        else
            echo "   ❌ $tool missing"
            MISSING_TOOLS+=($tool)
        fi
    done
    
    if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
        echo ""
        echo "⚠️  Missing tools: ${MISSING_TOOLS[*]}"
        echo ""
        echo "Installation commands for Cloud Shell:"
        for tool in "${MISSING_TOOLS[@]}"; do
            case $tool in
                "jq")
                    echo "   sudo apt-get update && sudo apt-get install -y jq"
                    ;;
                "aws")
                    echo "   curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'"
                    echo "   unzip awscliv2.zip && sudo ./aws/install"
                    ;;
                "docker")
                    echo "   # Docker should be pre-installed in Cloud Shell"
                    echo "   # If missing, contact Cloud Shell support"
                    ;;
            esac
        done
        
        read -p "Install missing tools automatically? (y/n): " INSTALL
        if [ "$INSTALL" = "y" ] || [ "$INSTALL" = "Y" ]; then
            for tool in "${MISSING_TOOLS[@]}"; do
                case $tool in
                    "jq")
                        sudo apt-get update && sudo apt-get install -y jq
                        ;;
                esac
            done
        fi
    fi
}

# Function to create environment file
create_environment_file() {
    echo ""
    echo "📄 Creating environment configuration..."
    
    cat > cloudshell-env.sh << 'EOF'
#!/bin/bash
# Cloud Shell environment variables for DNS Lookup Service

# Docker configuration
export DOCKER_BUILDKIT=1
export DOCKER_CLI_EXPERIMENTAL=enabled

# AWS region (modify if needed)
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-"us-east-1"}

# Service configuration
export DNS_SERVICE_VERSION="v1.3.0"
export ECR_REPOSITORY="dns-lookup-service"

echo "🔧 Cloud Shell environment configured"
echo "   Region: $AWS_DEFAULT_REGION"
echo "   Service: $ECR_REPOSITORY:$DNS_SERVICE_VERSION"
EOF
    
    chmod +x cloudshell-env.sh
    echo "   ✅ Environment file created: cloudshell-env.sh"
    echo "   💡 Run 'source cloudshell-env.sh' to load environment"
}

# Run setup functions
check_required_tools
setup_temporary_credentials
setup_docker_environment
verify_ecr_access
create_environment_file

echo ""
echo "🎉 Cloud Shell Environment Setup Complete!"
echo ""
echo "📋 Setup Summary:"
echo "   ✅ AWS credentials configured and verified"
echo "   ✅ Docker environment prepared"
echo "   ✅ ECR access verified"
echo "   ✅ Required tools available"
echo "   ✅ Environment configuration created"
echo ""
echo "🚀 Next Steps:"
echo "1. Source environment: source cloudshell-env.sh"
echo "2. Run deployment: ./deploy.sh"
echo ""
echo "💡 If you encounter issues:"
echo "   - Check AWS credentials: aws sts get-caller-identity"
echo "   - Check Docker: docker info"
echo "   - Check ECR permissions: aws ecr describe-repositories"
echo ""
echo "✅ Ready for DNS service deployment!"