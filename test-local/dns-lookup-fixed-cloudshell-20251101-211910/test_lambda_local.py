#!/usr/bin/env python3
import sys
import json

# Test direct import
try:
    from lambda_handler import lambda_handler
    print("✅ Lambda handler imported successfully")
except ImportError as e:
    print(f"❌ Import failed: {e}")
    sys.exit(1)

# Test basic function call
test_events = [
    {"domain": "google.com"},
    {"queryStringParameters": {"domain": "aws.amazon.com"}},
    {"body": '{"domain": "github.com"}'}
]

for i, event in enumerate(test_events, 1):
    try:
        print(f"\n🔄 Test {i}: {event}")
        result = lambda_handler(event, {})
        print(f"✅ Result: {json.dumps(result, indent=2)}")
    except Exception as e:
        print(f"❌ Error: {e}")

print("\n🎉 Lambda handler tests completed!")
