#!/bin/bash
# Copy files for Fixed HTTP Container Theory Test
# This tests if simple HTTP works with fixed application logic (no MCP needed)

echo "🧪 TESTING THEORY: Fixed HTTP Container vs MCP Container"
echo "Copying files to test if HTTP works with corrected application logic..."
echo ""

# CRITICAL: Fixed application logic (the real fix)
echo "📋 Core Application Files (REQUIRED):"
cp chatops_route_dns_intent.py /home/bharat/
echo "✅ chatops_route_dns_intent.py (FIXED - Route53 error handling + mock data)"

cp chatops_helpers.py /home/bharat/ 
echo "✅ chatops_helpers.py (SSM configuration helper)"

# CRITICAL: Simple HTTP container handler (original approach)
echo ""
echo "🌐 HTTP Container Handler:"
cp container_handler.py /home/bharat/
echo "✅ container_handler.py (Original HTTP handler - should work now with fixed logic)"

# CRITICAL: Simple Dockerfile for HTTP container
echo ""
echo "🐳 Container Configuration:"
cp Dockerfile.simple /home/bharat/
echo "✅ Dockerfile.simple (ARM64 container with correct env vars)"

cp requirements.txt /home/bharat/
echo "✅ requirements.txt (Python dependencies)"

# OPTIONAL: Test files for validation
echo ""
echo "🧪 Test & Debug Files:"
cp test_lambda_local.py /home/bharat/
echo "✅ test_lambda_local.py (Local testing)"

cp debug_detailed.py /home/bharat/
echo "✅ debug_detailed.py (Detailed debugging)"

# COMPARISON: MCP files for reference
echo ""
echo "📚 MCP Files (for comparison):"
cp container_handler_mcp.py /home/bharat/
echo "✅ container_handler_mcp.py (MCP handler - for reference)"

echo ""
echo "🎯 THEORY TEST PLAN:"
echo "1. Test locally: python3 test_lambda_local.py"
echo "2. Build HTTP container: docker build -t dns-lookup-http:v9.0.0-theory-test -f Dockerfile.simple ."
echo "3. Compare with MCP approach"
echo "4. Deploy HTTP container to prove HTTP works with fixed logic"
echo ""
echo "📁 Files copied to /home/bharat/:"