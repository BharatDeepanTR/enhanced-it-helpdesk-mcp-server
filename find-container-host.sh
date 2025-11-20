#!/bin/bash
# Script to discover your container host endpoint

echo "🔍 Discovering Your Container Host..."
echo ""

echo "📋 Checking ECS Services:"
aws ecs list-clusters --region us-east-1 --query 'clusterArns[*]' --output table 2>/dev/null || echo "❌ No ECS access or clusters found"

if aws ecs list-clusters --region us-east-1 >/dev/null 2>&1; then
    echo "🔍 Searching for DNS lookup service in ECS..."
    for cluster in $(aws ecs list-clusters --region us-east-1 --query 'clusterArns[*]' --output text); do
        cluster_name=$(basename $cluster)
        echo "Checking cluster: $cluster_name"
        aws ecs list-services --cluster $cluster_name --region us-east-1 --query 'serviceArns[*]' --output table 2>/dev/null
    done
fi

echo ""
echo "📋 Checking EKS Clusters:"
aws eks list-clusters --region us-east-1 --query 'clusters[*]' --output table 2>/dev/null || echo "❌ No EKS access or clusters found"

echo ""
echo "📋 Checking Lambda Functions:"
aws lambda list-functions --region us-east-1 --query 'Functions[?contains(FunctionName, `dns`) || contains(FunctionName, `lookup`)].FunctionName' --output table 2>/dev/null || echo "❌ No Lambda access"

echo ""
echo "🎯 Common Container Host Patterns:"
echo ""
echo "1. ECS/Fargate with ALB:"
echo "   Format: {alb-dns-name}"
echo "   Example: dns-lookup-alb-123456789.us-east-1.elb.amazonaws.com"
echo ""
echo "2. ECS/Fargate with NLB:"
echo "   Format: {nlb-dns-name}"  
echo "   Example: dns-lookup-nlb-123456789.us-east-1.elb.amazonaws.com"
echo ""
echo "3. EKS with LoadBalancer:"
echo "   Format: {external-ip} or {lb-hostname}"
echo "   Example: a1234567890.elb.us-east-1.amazonaws.com"
echo ""
echo "4. Direct ECS Task (if public):"
echo "   Format: {task-public-ip}:8080"
echo "   Example: 54.123.456.789:8080"
echo ""
echo "5. Lambda Function URL:"
echo "   Format: https://{function-url-id}.lambda-url.{region}.on.aws/"
echo ""
echo "🔧 Next Steps:"
echo "1. Check AWS Console for your deployed service"
echo "2. Look for Load Balancer DNS name or Public IP"
echo "3. Test with: curl http://{your-endpoint}:8080/health"