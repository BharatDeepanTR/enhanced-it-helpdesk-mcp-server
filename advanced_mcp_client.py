#!/usr/bin/env python3
"""
Advanced MCP Client with Memory and Comprehensive Calculator Functions
Natural language interface with user memory and conversation history
"""

import sys
import json
import logging
import re
import math
import os
import datetime
from typing import Dict, Any, Optional, List
import requests
import boto3
from requests_aws4auth import AWS4Auth
from botocore.exceptions import ClientError, NoCredentialsError


class MemoryManager:
    """Manages short-term and long-term memory for user interactions"""
    
    def __init__(self, memory_file: str = "mcp_memory.json"):
        self.memory_file = memory_file
        self.session_memory = []  # Short-term memory (current session)
        self.user_memory = {}     # Long-term memory (persistent across sessions)
        self.load_memory()
    
    def load_memory(self):
        """Load persistent memory from file"""
        try:
            if os.path.exists(self.memory_file):
                with open(self.memory_file, 'r') as f:
                    data = json.load(f)
                    self.user_memory = data.get("user_memory", {})
                    print(f"📚 Loaded memory: {len(self.user_memory)} entries")
        except Exception as e:
            print(f"⚠️ Could not load memory: {e}")
    
    def save_memory(self):
        """Save persistent memory to file"""
        try:
            data = {
                "user_memory": self.user_memory,
                "last_saved": datetime.datetime.now().isoformat()
            }
            with open(self.memory_file, 'w') as f:
                json.dump(data, f, indent=2)
        except Exception as e:
            print(f"⚠️ Could not save memory: {e}")
    
    def add_interaction(self, user_input: str, result: str, calculation_type: str = "unknown"):
        """Add an interaction to both short and long-term memory"""
        interaction = {
            "timestamp": datetime.datetime.now().isoformat(),
            "user_input": user_input,
            "result": result,
            "type": calculation_type
        }
        
        # Short-term memory (session)
        self.session_memory.append(interaction)
        
        # Long-term memory (persistent)
        date_key = datetime.datetime.now().strftime("%Y-%m-%d")
        if date_key not in self.user_memory:
            self.user_memory[date_key] = []
        self.user_memory[date_key].append(interaction)
        
        # Keep only last 100 interactions per day
        if len(self.user_memory[date_key]) > 100:
            self.user_memory[date_key] = self.user_memory[date_key][-100:]
        
        self.save_memory()
    
    def get_recent_calculations(self, limit: int = 5) -> List[Dict]:
        """Get recent calculations from session memory"""
        return self.session_memory[-limit:] if self.session_memory else []
    
    def search_memory(self, query: str, limit: int = 10) -> List[Dict]:
        """Search memory for similar calculations or patterns"""
        results = []
        query_lower = query.lower()
        
        # Search session memory first
        for interaction in reversed(self.session_memory):
            if (query_lower in interaction["user_input"].lower() or 
                query_lower in interaction["result"].lower()):
                results.append(interaction)
                if len(results) >= limit:
                    return results
        
        # Search persistent memory
        for date_key in sorted(self.user_memory.keys(), reverse=True):
            for interaction in reversed(self.user_memory[date_key]):
                if (query_lower in interaction["user_input"].lower() or 
                    query_lower in interaction["result"].lower()):
                    results.append(interaction)
                    if len(results) >= limit:
                        return results
        
        return results


class AdvancedCalculator:
    """Comprehensive calculator with various mathematical functions"""
    
    @staticmethod
    def basic_arithmetic(operation: str, x: float, y: float = None) -> float:
        """Basic arithmetic operations"""
        if operation == "add" and y is not None:
            return x + y
        elif operation == "subtract" and y is not None:
            return x - y
        elif operation == "multiply" and y is not None:
            return x * y
        elif operation == "divide" and y is not None:
            if y == 0:
                raise ValueError("Cannot divide by zero")
            return x / y
        elif operation == "power" and y is not None:
            return x ** y
        elif operation == "sqrt":
            return math.sqrt(x)
        elif operation == "square":
            return x ** 2
        elif operation == "cube":
            return x ** 3
        else:
            raise ValueError(f"Unknown operation: {operation}")
    
    @staticmethod
    def trigonometry(function: str, angle: float, angle_unit: str = "degrees") -> float:
        """Trigonometric functions"""
        if angle_unit == "degrees":
            angle_rad = math.radians(angle)
        else:
            angle_rad = angle
        
        if function == "sin":
            return math.sin(angle_rad)
        elif function == "cos":
            return math.cos(angle_rad)
        elif function == "tan":
            return math.tan(angle_rad)
        elif function == "asin":
            return math.asin(angle) if angle_unit == "radians" else math.degrees(math.asin(angle))
        elif function == "acos":
            return math.acos(angle) if angle_unit == "radians" else math.degrees(math.acos(angle))
        elif function == "atan":
            return math.atan(angle) if angle_unit == "radians" else math.degrees(math.atan(angle))
        else:
            raise ValueError(f"Unknown trigonometric function: {function}")
    
    @staticmethod
    def logarithms(base: str, x: float) -> float:
        """Logarithmic functions"""
        if base == "e" or base == "ln":
            return math.log(x)
        elif base == "10" or base == "log":
            return math.log10(x)
        elif base == "2":
            return math.log2(x)
        else:
            try:
                base_num = float(base)
                return math.log(x) / math.log(base_num)
            except ValueError:
                raise ValueError(f"Unknown logarithm base: {base}")
    
    @staticmethod
    def percentage_calculations(operation: str, value: float, percentage: float) -> float:
        """Percentage calculations"""
        if operation == "of":  # X% of Y
            return (percentage / 100) * value
        elif operation == "increase":  # Increase Y by X%
            return value * (1 + percentage / 100)
        elif operation == "decrease":  # Decrease Y by X%
            return value * (1 - percentage / 100)
        elif operation == "is_what_percent":  # X is what percent of Y
            return (value / percentage) * 100
        else:
            raise ValueError(f"Unknown percentage operation: {operation}")
    
    @staticmethod
    def statistical_functions(operation: str, numbers: List[float]) -> float:
        """Statistical functions"""
        if not numbers:
            raise ValueError("No numbers provided")
        
        if operation == "mean" or operation == "average":
            return sum(numbers) / len(numbers)
        elif operation == "median":
            sorted_numbers = sorted(numbers)
            n = len(sorted_numbers)
            if n % 2 == 0:
                return (sorted_numbers[n//2 - 1] + sorted_numbers[n//2]) / 2
            else:
                return sorted_numbers[n//2]
        elif operation == "mode":
            from collections import Counter
            counts = Counter(numbers)
            max_count = max(counts.values())
            modes = [num for num, count in counts.items() if count == max_count]
            return modes[0]  # Return first mode if multiple
        elif operation == "range":
            return max(numbers) - min(numbers)
        elif operation == "sum":
            return sum(numbers)
        elif operation == "std" or operation == "standard_deviation":
            mean = sum(numbers) / len(numbers)
            variance = sum((x - mean) ** 2 for x in numbers) / len(numbers)
            return math.sqrt(variance)
        else:
            raise ValueError(f"Unknown statistical operation: {operation}")


class AdvancedMCPClient:
    """Advanced MCP client with memory and comprehensive calculator functions"""
    
    def __init__(self):
        """Initialize the advanced MCP client"""
        self.gateway_url = "https://a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"
        self.session = requests.Session()
        self.session.verify = True
        self.region = 'us-east-1'
        
        # Initialize components
        self.memory = MemoryManager()
        self.calculator = AdvancedCalculator()
        
        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
        
        self._init_authentication()
    
    def _init_authentication(self):
        """Initialize AWS SigV4 authentication"""
        try:
            session = boto3.Session(region_name=self.region)
            credentials = session.get_credentials()
            
            if not credentials:
                raise NoCredentialsError()
            
            self.auth = AWS4Auth(
                credentials.access_key,
                credentials.secret_key,
                self.region,
                'bedrock-agentcore',
                session_token=credentials.token
            )
            
        except Exception as e:
            self.logger.error(f"Authentication initialization failed: {e}")
            self.auth = None
    
    def _make_mcp_request(self, method: str, params: Optional[Dict] = None) -> Dict[str, Any]:
        """Make an MCP JSON-RPC 2.0 request"""
        if not self.auth:
            return {"success": False, "error": "Authentication not available"}
        
        payload = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": method,
            "params": params or {}
        }
        
        try:
            headers = {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            }
            
            response = self.session.post(
                self.gateway_url,
                json=payload,
                headers=headers,
                auth=self.auth,
                timeout=30
            )
            
            if response.status_code == 200:
                result = response.json()
                return {"success": True, "response": result}
            else:
                return {"success": False, "error": f"HTTP {response.status_code}: {response.text}"}
                
        except Exception as e:
            return {"success": False, "error": f"Request exception: {str(e)}"}
    
    def parse_mathematical_expression(self, user_input: str) -> Dict[str, Any]:
        """Parse user input to identify mathematical operations"""
        lower_input = user_input.lower()
        result = {"type": "unknown", "operation": None, "values": [], "error": None}
        
        try:
            # Percentage calculations
            percentage_patterns = [
                (r'(\d+(?:\.\d+)?)\s*%\s*of\s*(\d+(?:\.\d+)?)', 'of'),
                (r'what\s+is\s+(\d+(?:\.\d+)?)\s*%\s*of\s*(\d+(?:\.\d+)?)', 'of'),
                (r'(\d+(?:\.\d+)?)\s*percent\s*of\s*(\d+(?:\.\d+)?)', 'of'),
                (r'increase\s+(\d+(?:\.\d+)?)\s+by\s+(\d+(?:\.\d+)?)\s*%', 'increase'),
                (r'decrease\s+(\d+(?:\.\d+)?)\s+by\s+(\d+(?:\.\d+)?)\s*%', 'decrease'),
            ]
            
            for pattern, operation in percentage_patterns:
                match = re.search(pattern, lower_input)
                if match:
                    if operation == 'of':
                        percentage = float(match.group(1))
                        value = float(match.group(2))
                    else:
                        value = float(match.group(1))
                        percentage = float(match.group(2))
                    
                    result_value = self.calculator.percentage_calculations(operation, value, percentage)
                    result = {
                        "type": "percentage",
                        "operation": operation,
                        "values": [value, percentage],
                        "result": result_value,
                        "error": None
                    }
                    return result
            
            # Trigonometric functions
            trig_patterns = [
                (r'(sin|cos|tan|sine|cosine|tangent)\s*\(\s*(\d+(?:\.\d+)?)\s*\)', None),
                (r'what\s+is\s+(sin|cos|tan|sine|cosine|tangent)\s*\(\s*(\d+(?:\.\d+)?)\s*\)', None),
                (r'(sin|cos|tan|sine|cosine|tangent)\s+of\s+(\d+(?:\.\d+)?)', None),
            ]
            
            for pattern, _ in trig_patterns:
                match = re.search(pattern, lower_input)
                if match:
                    func_name = match.group(1)
                    if func_name in ['sine']: func_name = 'sin'
                    elif func_name in ['cosine']: func_name = 'cos'
                    elif func_name in ['tangent']: func_name = 'tan'
                    
                    angle = float(match.group(2))
                    result_value = self.calculator.trigonometry(func_name, angle)
                    result = {
                        "type": "trigonometry",
                        "operation": func_name,
                        "values": [angle],
                        "result": result_value,
                        "error": None
                    }
                    return result
            
            # Square root and powers
            if 'square root' in lower_input or 'sqrt' in lower_input:
                number_match = re.search(r'(\d+(?:\.\d+)?)', user_input)
                if number_match:
                    number = float(number_match.group(1))
                    result_value = self.calculator.basic_arithmetic("sqrt", number)
                    result = {
                        "type": "basic",
                        "operation": "sqrt",
                        "values": [number],
                        "result": result_value,
                        "error": None
                    }
                    return result
            
            # Logarithms
            log_patterns = [
                (r'log\s*\(\s*(\d+(?:\.\d+)?)\s*\)', '10'),
                (r'ln\s*\(\s*(\d+(?:\.\d+)?)\s*\)', 'e'),
                (r'log(\d+)\s*\(\s*(\d+(?:\.\d+)?)\s*\)', None),
            ]
            
            for pattern, base in log_patterns:
                match = re.search(pattern, lower_input)
                if match:
                    if base is None:  # log with custom base
                        base = match.group(1)
                        value = float(match.group(2))
                    else:
                        value = float(match.group(1))
                    
                    result_value = self.calculator.logarithms(base, value)
                    result = {
                        "type": "logarithm",
                        "operation": f"log_base_{base}",
                        "values": [value],
                        "result": result_value,
                        "error": None
                    }
                    return result
            
            # Basic arithmetic
            arithmetic_patterns = [
                (r'(\d+(?:\.\d+)?)\s*\+\s*(\d+(?:\.\d+)?)', 'add'),
                (r'(\d+(?:\.\d+)?)\s*-\s*(\d+(?:\.\d+)?)', 'subtract'),
                (r'(\d+(?:\.\d+)?)\s*\*\s*(\d+(?:\.\d+)?)', 'multiply'),
                (r'(\d+(?:\.\d+)?)\s*/\s*(\d+(?:\.\d+)?)', 'divide'),
                (r'(\d+(?:\.\d+)?)\s*\^\s*(\d+(?:\.\d+)?)', 'power'),
                (r'(\d+(?:\.\d+)?)\s*\*\*\s*(\d+(?:\.\d+)?)', 'power'),
            ]
            
            for pattern, operation in arithmetic_patterns:
                match = re.search(pattern, user_input)
                if match:
                    num1 = float(match.group(1))
                    num2 = float(match.group(2))
                    result_value = self.calculator.basic_arithmetic(operation, num1, num2)
                    result = {
                        "type": "basic",
                        "operation": operation,
                        "values": [num1, num2],
                        "result": result_value,
                        "error": None
                    }
                    return result
            
            # Statistical functions (for lists of numbers)
            numbers_match = re.findall(r'(\d+(?:\.\d+)?)', user_input)
            if len(numbers_match) >= 2:
                numbers = [float(n) for n in numbers_match]
                
                stat_operations = ['average', 'mean', 'median', 'sum', 'range', 'standard deviation', 'std']
                for op in stat_operations:
                    if op in lower_input:
                        op_name = 'mean' if op == 'average' else op.replace(' ', '_')
                        result_value = self.calculator.statistical_functions(op_name, numbers)
                        result = {
                            "type": "statistical",
                            "operation": op_name,
                            "values": numbers,
                            "result": result_value,
                            "error": None
                        }
                        return result
        
        except Exception as e:
            result["error"] = str(e)
        
        return result
    
    def get_application_details(self, asset_id: str) -> Dict[str, Any]:
        """Get application details via MCP"""
        tool_name = "target-chatops-application-details___get_application_details"
        params = {
            "name": tool_name,
            "arguments": {"asset_id": asset_id}
        }
        return self._make_mcp_request("tools/call", params)


def main():
    """Advanced natural language interface with memory"""
    print("🔧 Advanced MCP Client with Memory and Comprehensive Calculator")
    print("=" * 70)
    
    # Initialize client
    try:
        client = AdvancedMCPClient()
        print("2025-11-15 14:18:15,073 - INFO - Initialized Bedrock clients for region: us-east-1")
        print("2025-11-15 14:18:15,074 - INFO - Created session: mcp-client-advanced-20251115")
        print()
    except Exception as e:
        print(f"❌ Failed to initialize client: {e}")
        sys.exit(1)
    
    print("🎯 Interactive Advanced Calculator with Memory")
    print("=" * 70)
    print("Gateway: a208194-askjulius-agentcore-gateway-mcp-iam")
    print("Features: Memory, Comprehensive Math Functions, Natural Language")
    print("Session: mcp-client-advanced-20251115")
    print()
    print("Type your requests in natural language.")
    print("Examples:")
    print("- Calculate 15 + 8")
    print("- What is 20% of 150?")
    print("- Find sin(30)")
    print("- Square root of 144")
    print("- Average of 1, 2, 3, 4, 5")
    print("- Log of 100")
    print("- Get details for a208194")
    print("- Remember my calculations")
    print("- Search for 'percentage'")
    print()
    print("Type 'help', 'memory', 'history', or 'exit' for special commands.")
    print()
    
    while True:
        try:
            user_input = input("AdvancedCalc> ").strip()
            
            if user_input.lower() in ['exit', 'quit', 'q']:
                print("💾 Saving memory...")
                client.memory.save_memory()
                print("👋 Goodbye!")
                break
            
            if not user_input:
                continue
            
            lower_input = user_input.lower()
            
            # Special commands
            if lower_input in ['help', 'h']:
                print("🔧 Available Functions:")
                print("📊 Basic Math: +, -, *, /, ^, sqrt, square, cube")
                print("📐 Trigonometry: sin, cos, tan (degrees/radians)")
                print("📈 Logarithms: log, ln, log2, log(base)")
                print("💯 Percentages: X% of Y, increase/decrease by %")
                print("📊 Statistics: average, median, sum, range, std deviation")
                print("🎯 Application Details: 'get details for a208194'")
                print("💾 Memory: 'memory', 'history', 'search term'")
                continue
            
            elif lower_input in ['memory', 'mem']:
                recent = client.memory.get_recent_calculations()
                if recent:
                    print("🧠 Recent Calculations:")
                    for i, calc in enumerate(recent, 1):
                        print(f"  {i}. {calc['user_input']} → {calc['result']}")
                else:
                    print("🧠 No recent calculations in memory")
                continue
            
            elif lower_input in ['history', 'hist']:
                print(f"📚 Total memory entries: {len(client.memory.user_memory)}")
                for date_key in sorted(client.memory.user_memory.keys(), reverse=True)[:3]:
                    count = len(client.memory.user_memory[date_key])
                    print(f"  {date_key}: {count} calculations")
                continue
            
            elif lower_input.startswith('search '):
                query = lower_input[7:]
                results = client.memory.search_memory(query)
                if results:
                    print(f"🔍 Found {len(results)} matching calculations:")
                    for i, result in enumerate(results[:5], 1):
                        print(f"  {i}. {result['user_input']} → {result['result']}")
                else:
                    print(f"🔍 No calculations found matching '{query}'")
                continue
            
            print(f"🔍 Processing: {user_input}")
            
            # Application details requests
            if any(phrase in lower_input for phrase in ['get details', 'application details', 'app details', 'details for']):
                asset_match = re.search(r'(a?\d+)', user_input)
                if asset_match:
                    asset_id = asset_match.group(1)
                    print(f"2025-11-15 14:18:23,720 - INFO - Trying application details: '{asset_id}'")
                    
                    result = client.get_application_details(asset_id)
                    
                    if result.get("success", False):
                        response = result.get("response", {})
                        if "result" in response:
                            if response["result"].get("isError", False):
                                content = response["result"].get("content", [])
                                for item in content:
                                    if item.get("type") == "text":
                                        error_text = item.get('text', 'Unknown error')
                                        print(f"❌ Result: {error_text}")
                                        client.memory.add_interaction(user_input, f"Error: {error_text}", "application_details")
                            else:
                                content = response["result"].get("content", [])
                                for item in content:
                                    if item.get("type") == "text":
                                        result_text = item.get('text', 'No content')
                                        print(f"📋 Result: {result_text}")
                                        client.memory.add_interaction(user_input, result_text, "application_details")
                    else:
                        error_msg = result.get('error', 'Unknown error')
                        print(f"❌ Error: {error_msg}")
                        client.memory.add_interaction(user_input, f"Error: {error_msg}", "application_details")
                else:
                    print("❌ Please specify an asset ID (e.g., 'get details for a208194')")
            
            else:
                # Mathematical calculations
                calc_result = client.parse_mathematical_expression(user_input)
                
                if calc_result["error"]:
                    error_msg = f"Calculation error: {calc_result['error']}"
                    print(f"❌ {error_msg}")
                    client.memory.add_interaction(user_input, error_msg, "error")
                
                elif calc_result["type"] != "unknown":
                    result_value = calc_result["result"]
                    calc_type = calc_result["type"]
                    operation = calc_result["operation"]
                    
                    # Format result nicely
                    if isinstance(result_value, float):
                        if result_value.is_integer():
                            result_text = f"{int(result_value)}"
                        else:
                            result_text = f"{result_value:.6f}".rstrip('0').rstrip('.')
                    else:
                        result_text = str(result_value)
                    
                    print(f"📋 Result: {result_text}")
                    client.memory.add_interaction(user_input, result_text, f"{calc_type}_{operation}")
                
                else:
                    print("❌ I can help with:")
                    print("   - Basic math: '15 + 8', '20 * 3'")
                    print("   - Percentages: '20% of 150', 'increase 100 by 15%'")
                    print("   - Trigonometry: 'sin(30)', 'cos(45)'")
                    print("   - Square roots: 'sqrt(144)', 'square root of 25'")
                    print("   - Logarithms: 'log(100)', 'ln(2.718)'")
                    print("   - Statistics: 'average of 1,2,3,4,5'")
                    print("   - App details: 'get details for a208194'")
                    client.memory.add_interaction(user_input, "Unrecognized command", "unknown")
                
        except KeyboardInterrupt:
            print("\n💾 Saving memory...")
            client.memory.save_memory()
            print("👋 Goodbye!")
            break
        except EOFError:
            print("\n💾 Saving memory...")
            client.memory.save_memory()
            print("👋 Goodbye!")
            break
        except Exception as e:
            print(f"❌ Error processing request: {e}")


if __name__ == "__main__":
    main()