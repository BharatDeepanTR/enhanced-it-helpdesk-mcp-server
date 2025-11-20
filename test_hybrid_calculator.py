import boto3
import json
import requests
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest

class HybridCalculatorTester:
    def __init__(self):
        self.session = boto3.Session()
        self.gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
        self.credentials = self.session.get_credentials()
        
    def sign_request(self, method, url, data=None):
        """Sign request with SigV4"""
        request = AWSRequest(method=method, url=url, data=data)
        SigV4Auth(self.credentials, "bedrock-agentcore", "us-east-1").add_auth(request)
        return dict(request.headers)
    
    def test_lambda_mcp_calculator(self, a=25, b=4):
        """Test structured Lambda MCP calculator"""
        print(f"🔢 Testing Lambda MCP Calculator: {a} + {b}")
        print("-" * 50)
        
        try:
            payload = {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "tools/call",
                "params": {
                    "name": "target-lambda-direct-calculator-mcp___add",
                    "arguments": {
                        "a": a,
                        "b": b
                    }
                }
            }
            
            headers = self.sign_request('POST', self.gateway_url, json.dumps(payload))
            headers['Content-Type'] = 'application/json'
            
            response = requests.post(self.gateway_url, json=payload, headers=headers)
            
            print(f"Status: {response.status_code}")
            result = response.json()
            
            if "result" in result and "content" in result["result"]:
                content = result["result"]["content"]
                if isinstance(content, list) and len(content) > 0:
                    text_result = content[0].get("text", "No text found")
                    print(f"✅ Lambda MCP Result: {text_result}")
                    return True
            
            print("❌ Lambda MCP failed")
            print(json.dumps(result, indent=2))
            return False
            
        except Exception as e:
            print(f"❌ Lambda MCP Error: {e}")
            return False
    
    def test_bedrock_ai_calculator(self, query="Calculate 25 plus 4 and explain the process step by step"):
        """Test AI-powered Bedrock calculator"""
        print(f"\n🧠 Testing Bedrock AI Calculator")
        print(f"Query: '{query}'")
        print("-" * 50)
        
        try:
            payload = {
                "jsonrpc": "2.0",
                "id": 2,
                "method": "tools/call",
                "params": {
                    "name": "target-bedrock-claude-calculator",
                    "arguments": {
                        "prompt": query
                    }
                }
            }
            
            headers = self.sign_request('POST', self.gateway_url, json.dumps(payload))
            headers['Content-Type'] = 'application/json'
            
            response = requests.post(self.gateway_url, json=payload, headers=headers)
            
            print(f"Status: {response.status_code}")
            result = response.json()
            
            if "result" in result and "content" in result["result"]:
                content = result["result"]["content"]
                if isinstance(content, list) and len(content) > 0:
                    text_result = content[0].get("text", "No text found")
                    print(f"✅ Bedrock AI Result:\n{text_result}")
                    return True
            
            print("❌ Bedrock AI failed")
            print(json.dumps(result, indent=2))
            return False
            
        except Exception as e:
            print(f"❌ Bedrock AI Error: {e}")
            return False
    
    def test_complex_ai_calculation(self):
        """Test complex calculation that showcases AI capabilities"""
        complex_query = """
        I have a loan of $50,000 at 4.5% annual interest, compounded monthly for 5 years. 
        Calculate the monthly payment and explain the formula used. 
        Also, tell me the total interest paid over the life of the loan.
        """
        
        print(f"\n🎯 Testing Complex AI Calculation")
        print(f"Query: {complex_query.strip()}")
        print("-" * 50)
        
        return self.test_bedrock_ai_calculator(complex_query.strip())
    
    def test_natural_language_math(self):
        """Test natural language math that Lambda MCP can't handle"""
        nl_queries = [
            "What is 15% of 240?",
            "Convert 5 feet 8 inches to centimeters",
            "If I invest $1000 at 7% annual return, how much will I have in 10 years with compound interest?",
            "Solve the quadratic equation: x² + 5x - 6 = 0"
        ]
        
        print(f"\n🗣️ Testing Natural Language Math Capabilities")
        print("=" * 60)
        
        ai_results = []
        
        for i, query in enumerate(nl_queries, 1):
            print(f"\n🧠 AI Query {i}: '{query}'")
            print("-" * 40)
            
            try:
                success = self.test_bedrock_ai_calculator(query)
                ai_results.append(success)
            except Exception as e:
                print(f"❌ Error: {e}")
                ai_results.append(False)
        
        return ai_results
    
    def run_comprehensive_comparison(self):
        """Compare Lambda MCP vs Bedrock AI approaches"""
        print("=" * 80)
        print("HYBRID CALCULATOR COMPARISON TEST")
        print("=" * 80)
        print(f"Gateway: {self.gateway_url}")
        print("=" * 80)
        
        # Test 1: Simple calculation - both approaches
        print("🔍 TEST 1: Simple Addition (Both Approaches)")
        lambda_success = self.test_lambda_mcp_calculator(25, 4)
        ai_basic_success = self.test_bedrock_ai_calculator("Calculate 25 + 4")
        
        # Test 2: Complex calculation - AI only
        print(f"\n🔍 TEST 2: Complex Financial Calculation (AI Only)")
        ai_complex_success = self.test_complex_ai_calculation()
        
        # Test 3: Natural language math - AI only
        print(f"\n🔍 TEST 3: Natural Language Math (AI Only)")
        nl_results = self.test_natural_language_math()
        
        # Results summary
        print("\n" + "=" * 80)
        print("COMPARISON RESULTS")
        print("=" * 80)
        
        print(f"🔢 Lambda MCP Calculator:")
        print(f"   ✅ Structured operations: {'✅' if lambda_success else '❌'}")
        print(f"   ⚡ Speed: Very fast (direct function calls)")
        print(f"   🎯 Precision: Exact mathematical results")
        print(f"   📊 Format: Structured, predictable responses")
        print(f"   💰 Cost: Low (Lambda execution time)")
        
        print(f"\n🧠 Bedrock AI Calculator:")
        print(f"   ✅ Basic math: {'✅' if ai_basic_success else '❌'}")
        print(f"   ✅ Complex calculations: {'✅' if ai_complex_success else '❌'}")
        print(f"   ✅ Natural language: {sum(nl_results)}/{len(nl_results)} queries successful")
        print(f"   🗣️ Explanations: Step-by-step reasoning")
        print(f"   🧮 Versatility: Handles any mathematical concept")
        print(f"   💰 Cost: Higher (model inference tokens)")
        
        print(f"\n🎯 RECOMMENDATIONS:")
        print(f"   • Use Lambda MCP for: Fast, precise, structured calculations")
        print(f"   • Use Bedrock AI for: Complex math, explanations, natural language")
        print(f"   • Hybrid approach gives you the best of both worlds!")
        
        return {
            "lambda_mcp": lambda_success,
            "ai_basic": ai_basic_success, 
            "ai_complex": ai_complex_success,
            "ai_natural_language": nl_results
        }

if __name__ == "__main__":
    tester = HybridCalculatorTester()
    results = tester.run_comprehensive_comparison()
    
    print("\n" + "=" * 80)
    print("NEXT STEPS")
    print("=" * 80)
    print("1. If Bedrock target isn't working yet, add it via AWS console")
    print("2. Test both approaches with your specific use cases")
    print("3. Choose the right tool for each type of calculation")
    print("4. Consider cost vs capability trade-offs")
    print("\n🚀 You now have both precision tools AND AI reasoning!")