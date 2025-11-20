#!/bin/bash
# Fixed container deployment script

echo "🔄 Pushing to existing ECR repository..."

# Tag and push to the correct existing repository
docker tag chatops-route-dns:v1.1.1-ping-fix 818565325759.dkr.ecr.us-east-1.amazonaws.com/chatops-route-dns:v1.1.1-ping-fix

# Try the push again
docker push 818565325759.dkr.ecr.us-east-1.amazonaws.com/chatops-route-dns:v1.1.1-ping-fix

if [ $? -eq 0 ]; then
    echo "✅ Container pushed successfully!"
    
    echo "🔄 Updating Agent Core Runtime with correct command..."
    
    # Use the correct AWS CLI command for updating runtime
    aws bedrock-agentcore update-agent-runtime \
        --runtime-id "a208194_chatops_route_dns_lookup-Zg3E6G5ZDV" \
        --container-configuration imageUri="818565325759.dkr.ecr.us-east-1.amazonaws.com/chatops-route-dns:v1.1.1-ping-fix" \
        --region us-east-1
    
    echo "✅ Runtime update command sent! Wait 2-3 minutes for redeployment."
    echo "📊 Monitor progress with: aws logs tail /aws/bedrock-agentcore/runtimes/a208194_chatops_route_dns_lookup-Zg3E6G5ZDV-DEFAULT --follow --region us-east-1"
    
else
    echo "❌ Push failed. Let me check the repository name..."
    aws ecr describe-repositories --region us-east-1 | grep repositoryName
fi