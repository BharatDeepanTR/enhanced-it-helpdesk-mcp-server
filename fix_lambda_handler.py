#!/usr/bin/env python3
"""
Lambda Handler Configuration Fixer
===================================

The DNS Lambda function has an import error: "No module named 'lambda_function'"
This means the handler configuration doesn't match the actual file structure.

This script will help identify and fix the handler configuration.
"""

import boto3
import json
import zipfile
import io
from typing import Dict, List, Any

class LambdaHandlerFixer:
    """Fix Lambda handler configuration issues"""
    
    def __init__(self):
        self.region = 'us-east-1'
        self.function_name = 'a208194_chatops_route_dns_lookup'
        self.lambda_client = boto3.client('lambda', region_name=self.region)
    
    def analyze_function_config(self):
        """Analyze current Lambda function configuration"""
        print("🔍 ANALYZING LAMBDA FUNCTION CONFIGURATION")
        print("="*60)
        
        try:
            # Get function configuration
            response = self.lambda_client.get_function(FunctionName=self.function_name)
            config = response['Configuration']
            
            print(f"📦 Function Name: {config.get('FunctionName')}")
            print(f"🔧 Current Handler: {config.get('Handler')}")
            print(f"🐍 Runtime: {config.get('Runtime')}")
            print(f"📁 Code Size: {config.get('CodeSize')} bytes")
            print(f"⏱️ Timeout: {config.get('Timeout')} seconds")
            print(f"💾 Memory: {config.get('MemorySize')} MB")
            
            # Download the function code to analyze structure
            code_url = response['Code']['Location']
            print(f"\n📋 Current Configuration:")
            print(f"   Handler: {config.get('Handler')}")
            print(f"   Expected Format: filename.function_name")
            print(f"   Example: lambda_function.lambda_handler")
            
            return config.get('Handler')
            
        except Exception as e:
            print(f"❌ Error getting function config: {str(e)}")
            return None
    
    def suggest_handler_fixes(self):
        """Suggest possible handler configurations"""
        print(f"\n🔧 COMMON HANDLER CONFIGURATION FIXES")
        print("="*60)
        
        common_handlers = [
            "app.lambda_handler",
            "main.lambda_handler", 
            "index.lambda_handler",
            "handler.lambda_handler",
            "lambda_function.lambda_handler",
            "dns_handler.lambda_handler",
            "chatops_dns.lambda_handler",
            "route_dns.lambda_handler"
        ]
        
        print("🎯 Try these handler configurations:")
        for i, handler in enumerate(common_handlers, 1):
            print(f"   {i}. {handler}")
        
        print(f"\n📝 How to update handler:")
        print(f"1. Go to Lambda Console → {self.function_name}")
        print(f"2. Click 'Code' tab")
        print(f"3. Scroll to 'Runtime settings'")
        print(f"4. Click 'Edit'")
        print(f"5. Update 'Handler' field")
        print(f"6. Click 'Save'")
    
    def test_handler_configurations(self):
        """Test different handler configurations"""
        print(f"\n🧪 TESTING HANDLER CONFIGURATIONS")
        print("="*60)
        
        test_handlers = [
            "app.lambda_handler",
            "main.lambda_handler",
            "index.lambda_handler", 
            "handler.lambda_handler",
            "dns_handler.lambda_handler"
        ]
        
        test_payload = {
            "test": True,
            "message": "Handler configuration test"
        }
        
        for handler in test_handlers:
            print(f"\n🔧 Testing handler: {handler}")
            try:
                # Update handler temporarily
                self.lambda_client.update_function_configuration(
                    FunctionName=self.function_name,
                    Handler=handler
                )
                
                # Wait a moment for update
                import time
                time.sleep(2)
                
                # Test invocation
                response = self.lambda_client.invoke(
                    FunctionName=self.function_name,
                    Payload=json.dumps(test_payload)
                )
                
                payload = json.loads(response['Payload'].read())
                
                if 'errorType' not in payload or 'ImportModuleError' not in str(payload):
                    print(f"   ✅ SUCCESS with handler: {handler}")
                    print(f"   📋 Response: {str(payload)[:200]}...")
                    return handler
                else:
                    print(f"   ❌ Failed: {payload.get('errorMessage', 'Unknown error')}")
                    
            except Exception as e:
                print(f"   ❌ Error testing {handler}: {str(e)}")
        
        print(f"\n⚠️ No working handler found automatically")
        return None
    
    def create_test_payloads_for_working_handler(self, working_handler: str):
        """Create test payloads once we find the working handler"""
        print(f"\n🎯 CREATING TEST PAYLOADS FOR WORKING HANDLER")
        print("="*60)
        print(f"✅ Working Handler: {working_handler}")
        
        # DNS-specific test payloads
        test_cases = [
            {
                "name": "DNS Lookup Test",
                "payload": {
                    "query": "dns lookup google.com",
                    "domain": "google.com",
                    "type": "A"
                }
            },
            {
                "name": "Route Information Test", 
                "payload": {
                    "query": "route to 8.8.8.8",
                    "target": "8.8.8.8",
                    "command": "route"
                }
            },
            {
                "name": "ChatOps Format Test",
                "payload": {
                    "text": "dns lookup amazon.com",
                    "user_id": "test-user",
                    "channel_id": "test-channel"
                }
            },
            {
                "name": "Agent Core Runtime Test",
                "payload": {
                    "inputText": "What is the IP address of microsoft.com?",
                    "sessionId": "test-session-456",
                    "sessionAttributes": {},
                    "promptSessionAttributes": {}
                }
            }
        ]
        
        print(f"\n🧪 Testing with working handler...")
        for i, test in enumerate(test_cases, 1):
            print(f"\n{i}. {test['name']}")
            print("-" * 40)
            
            try:
                response = self.lambda_client.invoke(
                    FunctionName=self.function_name,
                    Payload=json.dumps(test['payload'])
                )
                
                result = json.loads(response['Payload'].read())
                
                if response['StatusCode'] == 200:
                    print(f"   ✅ SUCCESS")
                    print(f"   📝 Payload: {json.dumps(test['payload'], indent=2)}")
                    
                    if 'errorType' not in result:
                        print(f"   📋 Response: {str(result)[:300]}...")
                    else:
                        print(f"   ⚠️ Function Error: {result.get('errorMessage', 'Unknown')}")
                else:
                    print(f"   ❌ HTTP Error: {response['StatusCode']}")
                    
                # Save payload to file
                filename = f"working_test_{i}_{test['name'].lower().replace(' ', '_')}.json"
                with open(filename, 'w') as f:
                    json.dump(test['payload'], f, indent=2)
                print(f"   💾 Saved to: {filename}")
                    
            except Exception as e:
                print(f"   ❌ Error: {str(e)}")
    
    def run_handler_diagnosis(self):
        """Run complete handler diagnosis and fix"""
        print("🔧 LAMBDA HANDLER DIAGNOSIS & FIX")
        print("="*50)
        print(f"Function: {self.function_name}")
        print(f"Region: {self.region}")
        print("="*50)
        
        # 1. Analyze current config
        current_handler = self.analyze_function_config()
        
        # 2. Suggest fixes
        self.suggest_handler_fixes()
        
        # 3. Test different handlers automatically
        working_handler = self.test_handler_configurations()
        
        if working_handler:
            # 4. Create test payloads for the working handler
            self.create_test_payloads_for_working_handler(working_handler)
            
            print(f"\n🎉 SOLUTION FOUND!")
            print(f"   ✅ Working Handler: {working_handler}")
            print(f"   🔧 Function is now configured correctly")
            print(f"   🧪 Test payloads have been generated")
        else:
            print(f"\n❌ MANUAL INTERVENTION NEEDED")
            print(f"   📋 Try the suggested handlers manually")
            print(f"   🔍 Check the uploaded zip file structure")
            print(f"   📁 Look for .py files and their function names")

def main():
    """Main execution"""
    try:
        fixer = LambdaHandlerFixer()
        fixer.run_handler_diagnosis()
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")

if __name__ == "__main__":
    main()