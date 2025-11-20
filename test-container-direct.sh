#!/bin/bash
# Test DNS Lookup Service on Agent Core Runtime (Direct Container)

echo "🧪 Testing DNS Lookup Service - Agent Core Runtime"
echo ""

# You need to replace this with your actual endpoint
CONTAINER_ENDPOINT=""

echo "📋 To find your container endpoint:"
echo "   1. Check Agent Core Runtime dashboard/console"
echo "   2. Look for service endpoint or container URL"
echo "   3. Should be format: http://hostname:8080 or https://hostname"
echo ""

if [ -z "$CONTAINER_ENDPOINT" ]; then
    echo "❌ Please set CONTAINER_ENDPOINT variable with your actual endpoint"
    echo ""
    echo "Example usage:"
    echo "   export CONTAINER_ENDPOINT='http://your-host:8080'"
    echo "   ./test-container-direct.sh"
    echo ""
    echo "Or edit this script and set:"
    echo "   CONTAINER_ENDPOINT='http://your-actual-endpoint:8080'"
    echo ""
    exit 1
fi

echo "🔍 Testing endpoint: $CONTAINER_ENDPOINT"
echo ""

# Test 1: Health Check
echo "1️⃣ Health Check Test:"
echo "   Command: curl ${CONTAINER_ENDPOINT}/health"
echo ""
if curl -s -m 10 "${CONTAINER_ENDPOINT}/health" 2>/dev/null; then
    echo "   ✅ Health check passed!"
else
    echo "   ❌ Health check failed!"
fi
echo ""

# Test 2: DNS Lookup
echo "2️⃣ DNS Lookup Test:"
echo "   Command: curl '${CONTAINER_ENDPOINT}/lookup?domain=aws.amazon.com'"
echo ""
if curl -s -m 10 "${CONTAINER_ENDPOINT}/lookup?domain=aws.amazon.com" 2>/dev/null; then
    echo "   ✅ DNS lookup test passed!"
else
    echo "   ❌ DNS lookup test failed!"
fi
echo ""

# Test 3: POST Method
echo "3️⃣ POST Method Test:"
echo "   Command: curl -X POST with JSON data"
echo ""
if curl -s -m 10 -X POST \
    -H "Content-Type: application/json" \
    -d '{"domain": "google.com"}' \
    "${CONTAINER_ENDPOINT}/lookup" 2>/dev/null; then
    echo "   ✅ POST method test passed!"
else
    echo "   ❌ POST method test failed!"
fi
echo ""

echo "🎯 Common Endpoint Formats for Agent Core Runtime:"
echo "   • http://agent-core-lb-123456.region.elb.amazonaws.com:8080"
echo "   • https://your-agent-runtime.company.com/dns-service"
echo "   • http://10.0.1.100:8080 (internal IP)"
echo "   • https://agent-runtime-gateway.example.com"
echo ""
echo "💡 If tests fail:"
echo "   1. Verify the endpoint URL is correct"
echo "   2. Check if port 8080 is accessible"
echo "   3. Try with/without :8080 port"
echo "   4. Check if HTTPS is required instead of HTTP"