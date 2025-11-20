#!/usr/bin/env python3
"""
Enterprise MCP Gateway Test Client
Based on working enterprise patterns with enhanced authentication and error handling
Compatible with CloudShell environment and AWS SigV4 authentication
"""

import json
import requests
import boto3
import time
import logging
from requests_aws4auth import AWS4Auth
from botocore.exceptions import ClientError, NoCredentialsError
from urllib.parse import urlparse

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class EnterpriseMCPGatewayClient:
    """
    Enterprise-grade MCP Gateway Client
    Features:
    - Robust AWS authentication with multiple fallback methods
    - Enhanced error handling and logging
    - Session management
    - Comprehensive testing capabilities
    """
    
    def __init__(self, gateway_url, target_name, region='us-east-1'):
        """
        Initialize Enterprise MCP Gateway Client
        
        Args:
            gateway_url: Full gateway URL
            target_name: MCP target name 
            region: AWS region
        """
        self.gateway_url = gateway_url
        self.target_name = target_name
        self.region = region
        self.session_id = f"enterprise-mcp-{int(time.time())}"
        
        # Initialize AWS session with enhanced credential handling
        self.session = None
        self.credentials = None
        self.auth = None
        self._initialize_aws_credentials()
        
        logger.info(f"Enterprise MCP Gateway Client Initialized")
        logger.info(f"Gateway: {gateway_url}")
        logger.info(f"Target: {target_name}")
        logger.info(f"Region: {region}")
        logger.info(f"Session ID: {self.session_id}")
        
    def _initialize_aws_credentials(self):
        """Initialize AWS credentials with multiple fallback methods"""
        try:
            # Method 1: Try default session (CloudShell, EC2 roles, etc.)
            self.session = boto3.Session()
            self.credentials = self.session.get_credentials()
            
            if self.credentials:
                # Create AWS4Auth with bedrock-agentcore service (WORKING PATTERN)
                self.auth = AWS4Auth(
                    self.credentials.access_key,
                    self.credentials.secret_key,
                    self.region,
                    'bedrock-agentcore',
                    session_token=self.credentials.token
                )
                
                # Verify credentials work
                sts = self.session.client('sts')
                identity = sts.get_caller_identity()
                logger.info(f"✅ AWS credentials validated")
                logger.info(f"Account: {identity.get('Account')}")
                logger.info(f"User/Role: {identity.get('Arn')}")
                logger.info(f"✅ Authentication initialized with bedrock-agentcore")
                return
                
        except Exception as e:
            logger.warning(f"Default credential method failed: {e}")
        
        # Method 2: Try environment variables explicitly
        try:
            import os
            if all(key in os.environ for key in ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY']):
                self.session = boto3.Session(
                    aws_access_key_id=os.environ['AWS_ACCESS_KEY_ID'],
                    aws_secret_access_key=os.environ['AWS_SECRET_ACCESS_KEY'],
                    aws_session_token=os.environ.get('AWS_SESSION_TOKEN'),
                    region_name=self.region
                )
                self.credentials = self.session.get_credentials()
                
                # Create AWS4Auth with bedrock-agentcore service (WORKING PATTERN)
                self.auth = AWS4Auth(
                    self.credentials.access_key,
                    self.credentials.secret_key,
                    self.region,
                    'bedrock-agentcore',
                    session_token=self.credentials.token
                )
                
                # Verify credentials
                sts = self.session.client('sts')
                identity = sts.get_caller_identity()
                logger.info(f"✅ Environment credentials validated")
                logger.info(f"Account: {identity.get('Account')}")
                logger.info(f"✅ Authentication initialized with bedrock-agentcore")
                return
                
        except Exception as e:
            logger.warning(f"Environment credential method failed: {e}")
        
        # Method 3: Try AWS CLI profile
        try:
            self.session = boto3.Session(profile_name='default')
            self.credentials = self.session.get_credentials()
            
            if self.credentials:
                # Create AWS4Auth with bedrock-agentcore service (WORKING PATTERN)
                self.auth = AWS4Auth(
                    self.credentials.access_key,
                    self.credentials.secret_key,
                    self.region,
                    'bedrock-agentcore',
                    session_token=self.credentials.token
                )
                
                sts = self.session.client('sts')
                identity = sts.get_caller_identity()
                logger.info(f"✅ Profile credentials validated")
                logger.info(f"Account: {identity.get('Account')}")
                logger.info(f"✅ Authentication initialized with bedrock-agentcore")
                return
                
        except Exception as e:
            logger.warning(f"Profile credential method failed: {e}")
        
        raise NoCredentialsError("Unable to locate AWS credentials. Please configure AWS credentials.")
    
    def _sign_request(self, method, url, headers, body=None):
        """This method is no longer needed - AWS4Auth handles signing automatically"""
        # Not needed with AWS4Auth - kept for compatibility
        return headers
    
    def send_mcp_request(self, method, params=None, request_id=None):
        """
        Send MCP JSON-RPC request to gateway with enterprise error handling
        
        Args:
            method: MCP method (e.g., 'initialize', 'tools/list', 'tools/call')
            params: Method parameters
            request_id: Request ID (auto-generated if not provided)
        
        Returns:
            Response JSON or None on error
        """
        if request_id is None:
            request_id = f"enterprise-req-{int(time.time())}"
        
        # Build MCP JSON-RPC request
        mcp_request = {
            "jsonrpc": "2.0",
            "id": request_id,
            "method": method
        }
        
        if params:
            mcp_request["params"] = params
        
        # Prepare HTTP request headers
        headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-MCP-Target': self.target_name,
            'User-Agent': 'Enterprise-MCP-Client/1.0'
        }
        
        body = json.dumps(mcp_request)
        
        logger.info(f"📤 Sending MCP Request: {method}")
        logger.debug(f"Request body: {body}")
        
        try:
            # Send request with retry logic using AWS4Auth (WORKING PATTERN)
            max_retries = 3
            for attempt in range(max_retries):
                try:
                    response = requests.post(
                        self.gateway_url,
                        headers=headers,
                        data=body,
                        auth=self.auth,  # Use AWS4Auth directly (WORKING PATTERN)
                        timeout=60  # Increased timeout for enterprise usage
                    )
                    
                    logger.info(f"📥 Response Status: {response.status_code}")
                    
                    if response.status_code == 200:
                        response_json = response.json()
                        logger.info(f"✅ Success: {method}")
                        logger.debug(f"Response: {json.dumps(response_json, indent=2)}")
                        return response_json
                    elif response.status_code in [401, 403]:
                        logger.error(f"❌ Authentication Error ({response.status_code}): {response.text}")
                        # Try to refresh credentials
                        if attempt < max_retries - 1:
                            logger.info("🔄 Attempting to refresh credentials...")
                            self._initialize_aws_credentials()
                            continue
                        return None
                    elif response.status_code >= 500:
                        logger.warning(f"⚠️ Server Error ({response.status_code}): {response.text}")
                        if attempt < max_retries - 1:
                            wait_time = 2 ** attempt
                            logger.info(f"Retrying in {wait_time} seconds...")
                            time.sleep(wait_time)
                            continue
                        return None
                    else:
                        logger.error(f"❌ Unexpected Error ({response.status_code}): {response.text}")
                        return None
                        
                except requests.exceptions.RequestException as e:
                    logger.warning(f"⚠️ Request exception (attempt {attempt + 1}): {e}")
                    if attempt < max_retries - 1:
                        time.sleep(2 ** attempt)
                        continue
                    raise
            
            return None
            
        except Exception as e:
            logger.error(f"❌ Request failed: {str(e)}")
            return None
    
    def test_initialize(self):
        """Test MCP initialize method"""
        logger.info("🔧 Testing MCP Initialize...")
        
        params = {
            "protocolVersion": "2024-11-05",
            "capabilities": {
                "tools": {}
            },
            "clientInfo": {
                "name": "Enterprise MCP Test Client",
                "version": "1.0.0"
            }
        }
        
        result = self.send_mcp_request("initialize", params)
        return result is not None
    
    def test_tools_list(self):
        """Test MCP tools/list method"""
        logger.info("📋 Testing Tools List...")
        
        result = self.send_mcp_request("tools/list")
        return result is not None
    
    def test_ai_calculate(self, query):
        """Test AI Calculate tool"""
        logger.info(f"🧮 Testing AI Calculate: '{query}'...")
        
        params = {
            "name": "ai_calculate",
            "arguments": {
                "query": query
            }
        }
        
        result = self.send_mcp_request("tools/call", params)
        return result is not None
    
    def test_explain_calculation(self, calculation):
        """Test Explain Calculation tool"""
        logger.info(f"📚 Testing Explain Calculation: '{calculation}'...")
        
        params = {
            "name": "explain_calculation", 
            "arguments": {
                "calculation": calculation
            }
        }
        
        result = self.send_mcp_request("tools/call", params)
        return result is not None
    
    def test_solve_word_problem(self, problem):
        """Test Solve Word Problem tool"""
        logger.info(f"📝 Testing Solve Word Problem: '{problem}'...")
        
        params = {
            "name": "solve_word_problem",
            "arguments": {
                "problem": problem
            }
        }
        
        result = self.send_mcp_request("tools/call", params)
        return result is not None
    
    def run_comprehensive_test_suite(self):
        """Run comprehensive test suite"""
        print("🎯 Enterprise MCP Gateway Test Suite")
        print("=" * 60)
        
        test_results = []
        
        # Test 1: Initialize
        print("\n1. 🔧 Testing MCP Initialize...")
        success = self.test_initialize()
        test_results.append(("Initialize", success))
        print(f"   Result: {'✅ PASS' if success else '❌ FAIL'}")
        
        # Test 2: Tools List
        print("\n2. 📋 Testing Tools List...")
        success = self.test_tools_list()
        test_results.append(("Tools List", success))
        print(f"   Result: {'✅ PASS' if success else '❌ FAIL'}")
        
        # Test 3: AI Calculate (Simple)
        print("\n3. 🧮 Testing AI Calculate (Simple)...")
        success = self.test_ai_calculate("What is 25 + 17?")
        test_results.append(("AI Calculate (Simple)", success))
        print(f"   Result: {'✅ PASS' if success else '❌ FAIL'}")
        
        # Test 4: AI Calculate (Complex)
        print("\n4. 🧮 Testing AI Calculate (Complex)...")
        success = self.test_ai_calculate("What is 15% of $50,000?")
        test_results.append(("AI Calculate (Complex)", success))
        print(f"   Result: {'✅ PASS' if success else '❌ FAIL'}")
        
        # Test 5: Explain Calculation
        print("\n5. 📚 Testing Explain Calculation...")
        success = self.test_explain_calculation("quadratic formula")
        test_results.append(("Explain Calculation", success))
        print(f"   Result: {'✅ PASS' if success else '❌ FAIL'}")
        
        # Test 6: Solve Word Problem
        print("\n6. 📝 Testing Solve Word Problem...")
        success = self.test_solve_word_problem("If a train travels 60 mph for 2.5 hours, how far does it go?")
        test_results.append(("Solve Word Problem", success))
        print(f"   Result: {'✅ PASS' if success else '❌ FAIL'}")
        
        # Summary
        print("\n" + "=" * 60)
        print("📊 TEST RESULTS SUMMARY")
        print("=" * 60)
        
        passed = sum(1 for _, success in test_results if success)
        total = len(test_results)
        
        for test_name, success in test_results:
            status = "✅ PASS" if success else "❌ FAIL"
            print(f"   {test_name:<25} {status}")
        
        print("\n🎯 Overall: {}/{} tests passed ({:.1f}%)".format(passed, total, (passed/total)*100))
        
        if passed == total:
            print("🎉 All tests passed! MCP Gateway is fully operational.")
        elif passed > 0:
            print("⚠️ Some tests failed. Check the details above.")
        else:
            print("❌ All tests failed. Check authentication and configuration.")
        
        return passed == total

def main():
    """Main test function"""
    print("🚀 Enterprise MCP Gateway Test Client")
    print("=" * 60)
    
    # Configuration - Update these values as needed
    GATEWAY_URL = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
    TARGET_NAME = "target-lambda-direct-ai-calculator-mcp"
    REGION = "us-east-1"
    
    try:
        # Initialize client
        client = EnterpriseMCPGatewayClient(GATEWAY_URL, TARGET_NAME, REGION)
        
        # Run comprehensive test suite
        success = client.run_comprehensive_test_suite()
        
        if success:
            print("\n🎊 SUCCESS: All tests passed!")
            exit(0)
        else:
            print("\n⚠️ WARNING: Some tests failed!")
            exit(1)
            
    except NoCredentialsError as e:
        print(f"\n❌ Credentials Error: {e}")
        print("\n🔧 Troubleshooting:")
        print("1. Ensure you're in AWS CloudShell or have AWS credentials configured")
        print("2. Check environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY")
        print("3. Verify AWS CLI is configured: aws configure list")
        print("4. For temporary credentials, ensure AWS_SESSION_TOKEN is set")
        exit(1)
        
    except Exception as e:
        print(f"\n❌ Unexpected Error: {e}")
        logger.exception("Unexpected error occurred")
        exit(1)

if __name__ == "__main__":
    main()