#!/usr/bin/env python3
"""
Find the correct calculator gateway URL
Based on the gateway name from the script
"""

def generate_gateway_urls():
    """Generate possible gateway URLs based on the script configuration"""
    
    gateway_name = "a208194-askjulius-agentcore-gateway-mcp-iam"
    region = "us-east-1"
    
    print("🔍 Finding Correct Calculator Gateway URL")
    print("=" * 50)
    print(f"Gateway Name: {gateway_name}")
    print(f"Region: {region}")
    print()
    
    # Common gateway URL patterns
    url_patterns = [
        f"https://{gateway_name}.gateway.bedrock-agentcore.{region}.amazonaws.com/mcp",
        f"https://{gateway_name}-1.gateway.bedrock-agentcore.{region}.amazonaws.com/mcp",
        f"https://{gateway_name}-2.gateway.bedrock-agentcore.{region}.amazonaws.com/mcp",
        f"https://{gateway_name}-fvro4phd59.gateway.bedrock-agentcore.{region}.amazonaws.com/mcp",
        f"https://{gateway_name}-abc123def4.gateway.bedrock-agentcore.{region}.amazonaws.com/mcp"
    ]
    
    print("📋 Possible Gateway URLs:")
    for i, url in enumerate(url_patterns, 1):
        print(f"{i}. {url}")
    
    print()
    print("💡 Based on your earlier working sessions, the calculator gateway URL should be:")
    print("   Different from the application details gateway")
    print()
    print("🔧 To find the exact URL:")
    print("1. Check AWS Console → Bedrock → Agent Core → Gateways")
    print("2. Look for calculator-related gateway")
    print("3. Or check your working calculator client from earlier sessions")
    print()
    
    # Current script configuration
    print("📝 Current Script Configuration:")
    print("   Gateway Name: a208194-askjulius-agentcore-gateway-mcp-iam")
    print("   Lambda ARN: arn:aws:lambda:us-east-1:818565325759:function:a208194-calculator-mcp-server")
    print("   Target Name: target-direct-calculator-lambda")
    print()
    
    print("❌ Problem: Our clients are using:")
    print("   https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp")
    print("   But this points to application details, not calculator!")

if __name__ == "__main__":
    generate_gateway_urls()