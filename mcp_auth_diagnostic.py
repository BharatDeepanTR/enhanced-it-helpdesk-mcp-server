#!/usr/bin/env python3
"""
MCP Gateway Authentication Diagnostic Tool
Tests different authentication methods and configurations
"""

import json
import uuid
import requests
import boto3
from requests_aws4auth import AWS4Auth
from datetime import datetime
import sys
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class MCPAuthDiagnostic:
    """
    Diagnostic tool to test different authentication methods with the MCP gateway
    """
    
    def __init__(self, gateway_url: str, region: str = "us-east-1"):
        self.gateway_url = gateway_url
        self.region = region
        self.session = boto3.Session()
        self.credentials = self.session.get_credentials()
        
        if not self.credentials:
            raise Exception("AWS credentials not found")
        
        logger.info(f"✅ AWS credentials loaded")
        logger.info(f"🌐 Gateway URL: {gateway_url}")
    
    def test_auth_method_1_bedrock_agentcore(self):
        """Test with bedrock-agentcore service name"""
        logger.info("🧪 Testing Auth Method 1: bedrock-agentcore service")
        
        auth = AWS4Auth(
            self.credentials.access_key,
            self.credentials.secret_key,
            self.region,
            'bedrock-agentcore',
            session_token=self.credentials.token
        )
        
        return self._make_test_request(auth, "bedrock-agentcore")
    
    def test_auth_method_2_bedrock(self):
        """Test with bedrock service name"""
        logger.info("🧪 Testing Auth Method 2: bedrock service")
        
        auth = AWS4Auth(
            self.credentials.access_key,
            self.credentials.secret_key,
            self.region,
            'bedrock',
            session_token=self.credentials.token
        )
        
        return self._make_test_request(auth, "bedrock")
    
    def test_auth_method_3_execute_api(self):
        """Test with execute-api service name"""
        logger.info("🧪 Testing Auth Method 3: execute-api service")
        
        auth = AWS4Auth(
            self.credentials.access_key,
            self.credentials.secret_key,
            self.region,
            'execute-api',
            session_token=self.credentials.token
        )
        
        return self._make_test_request(auth, "execute-api")
    
    def test_auth_method_4_no_auth(self):
        """Test without authentication"""
        logger.info("🧪 Testing Auth Method 4: No authentication")
        
        return self._make_test_request(None, "no-auth")
    
    def test_auth_method_5_bearer_token(self):
        """Test with Bearer token from STS"""
        logger.info("🧪 Testing Auth Method 5: Bearer token")
        
        try:
            # Get temporary credentials
            sts_client = boto3.client('sts', region_name=self.region)
            response = sts_client.get_session_token()
            
            token = response['Credentials']['SessionToken']
            
            headers = {
                'Authorization': f'Bearer {token}',
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            }
            
            return self._make_test_request_with_headers(headers, "bearer-token")
            
        except Exception as e:
            logger.error(f"❌ Bearer token test failed: {e}")
            return False
    
    def test_auth_method_6_iam_headers(self):
        """Test with explicit IAM headers"""
        logger.info("🧪 Testing Auth Method 6: IAM headers")
        
        try:
            headers = {
                'X-Amz-Security-Token': self.credentials.token,
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            }
            
            return self._make_test_request_with_headers(headers, "iam-headers")
            
        except Exception as e:
            logger.error(f"❌ IAM headers test failed: {e}")
            return False
    
    def _make_test_request(self, auth, method_name):
        """Make test request with given auth"""
        payload = {
            "jsonrpc": "2.0",
            "method": "tools/list",
            "id": str(uuid.uuid4())
        }
        
        headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
        
        try:
            if auth:
                response = requests.post(
                    self.gateway_url,
                    json=payload,
                    headers=headers,
                    auth=auth,
                    timeout=30
                )
            else:
                response = requests.post(
                    self.gateway_url,
                    json=payload,
                    headers=headers,
                    timeout=30
                )
            
            logger.info(f"   📥 Status: {response.status_code}")
            
            if response.status_code == 200:
                logger.info(f"   ✅ {method_name} authentication SUCCESSFUL!")
                result = response.json()
                logger.info(f"   📋 Response: {json.dumps(result, indent=2)}")
                return True
            else:
                logger.error(f"   ❌ {method_name} authentication failed: {response.status_code}")
                logger.error(f"   📥 Error: {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"   ❌ {method_name} request exception: {e}")
            return False
    
    def _make_test_request_with_headers(self, headers, method_name):
        """Make test request with custom headers"""
        payload = {
            "jsonrpc": "2.0",
            "method": "tools/list",
            "id": str(uuid.uuid4())
        }
        
        try:
            response = requests.post(
                self.gateway_url,
                json=payload,
                headers=headers,
                timeout=30
            )
            
            logger.info(f"   📥 Status: {response.status_code}")
            
            if response.status_code == 200:
                logger.info(f"   ✅ {method_name} authentication SUCCESSFUL!")
                result = response.json()
                logger.info(f"   📋 Response: {json.dumps(result, indent=2)}")
                return True
            else:
                logger.error(f"   ❌ {method_name} authentication failed: {response.status_code}")
                logger.error(f"   📥 Error: {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"   ❌ {method_name} request exception: {e}")
            return False
    
    def run_comprehensive_auth_test(self):
        """Run all authentication tests"""
        print("🔍 MCP Gateway Authentication Diagnostic")
        print("=" * 50)
        print(f"Gateway URL: {self.gateway_url}")
        print(f"Region: {self.region}")
        print(f"Account: {boto3.client('sts').get_caller_identity()['Account']}")
        print("")
        
        methods = [
            self.test_auth_method_1_bedrock_agentcore,
            self.test_auth_method_2_bedrock,
            self.test_auth_method_3_execute_api,
            self.test_auth_method_4_no_auth,
            self.test_auth_method_5_bearer_token,
            self.test_auth_method_6_iam_headers
        ]
        
        successful_methods = []
        
        for i, method in enumerate(methods, 1):
            print(f"\n🔧 Test {i}/6")
            print("-" * 20)
            
            try:
                if method():
                    successful_methods.append(method.__name__)
            except Exception as e:
                logger.error(f"❌ Test {i} failed with exception: {e}")
        
        print("\n📊 Authentication Test Summary")
        print("=" * 40)
        print(f"Total tests: {len(methods)}")
        print(f"Successful: {len(successful_methods)}")
        print(f"Failed: {len(methods) - len(successful_methods)}")
        
        if successful_methods:
            print("\n✅ Successful authentication methods:")
            for method in successful_methods:
                print(f"   • {method}")
        else:
            print("\n❌ No authentication methods worked")
            print("\n🔍 Troubleshooting suggestions:")
            print("   1. Check if gateway is properly created and active")
            print("   2. Verify gateway URL is correct")
            print("   3. Check IAM permissions for your role")
            print("   4. Try creating gateway with different auth config")
            print("   5. Check gateway logs in CloudWatch")

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 mcp_auth_diagnostic.py <gateway_url> [region]")
        print("Example: python3 mcp_auth_diagnostic.py https://gateway.../mcp us-east-1")
        sys.exit(1)
    
    gateway_url = sys.argv[1]
    region = sys.argv[2] if len(sys.argv) > 2 else "us-east-1"
    
    try:
        diagnostic = MCPAuthDiagnostic(gateway_url, region)
        diagnostic.run_comprehensive_auth_test()
    except Exception as e:
        logger.error(f"❌ Diagnostic failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()