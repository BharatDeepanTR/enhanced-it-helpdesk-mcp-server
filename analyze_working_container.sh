#!/bin/bash
# Analyze working Agent Core Runtime container

echo "=== ANALYZING WORKING AGENT CORE RUNTIME ==="
echo "Working Runtime: a208194_askjulius_account_details_agent-PduynTEUSW"
echo "Working Container: 818565325759.dkr.ecr.us-east-1.amazonaws.com/208194-askjulius-account-details-ecr:6daae7bc"
echo ""

# Pull the working container
echo "Pulling working container..."
docker pull 818565325759.dkr.ecr.us-east-1.amazonaws.com/208194-askjulius-account-details-ecr:6daae7bc

# Inspect the container
echo ""
echo "=== CONTAINER INSPECTION ==="
docker inspect 818565325759.dkr.ecr.us-east-1.amazonaws.com/208194-askjulius-account-details-ecr:6daae7bc --format='{{json .Config}}' | python3 -m json.tool

# Try to run it temporarily to see what it does
echo ""
echo "=== ATTEMPTING TO ANALYZE ENTRYPOINT ==="
docker run --rm --entrypoint="" 818565325759.dkr.ecr.us-east-1.amazonaws.com/208194-askjulius-account-details-ecr:6daae7bc ls -la /app/ || echo "Cannot list container contents"

echo ""
echo "=== CHECKING CONTAINER COMMANDS ==="
docker run --rm --entrypoint="" 818565325759.dkr.ecr.us-east-1.amazonaws.com/208194-askjulius-account-details-ecr:6daae7bc cat /app/Dockerfile 2>/dev/null || echo "No Dockerfile found"

echo ""
echo "=== ANALYSIS COMPLETE ==="