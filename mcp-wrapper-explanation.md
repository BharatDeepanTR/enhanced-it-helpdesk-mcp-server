# 🔧 MCP Wrapper Lambda - Complete Technical Explanation

## 🎯 **The Problem We're Solving**

### **Original Issue:**
```
Bedrock Agent Core Gateway → Your Lambda Function
                            ↓
                    Returns: UnknownOperationException
```

**Why this happens:**
- Your Lambda function (`a208194-chatops_application_details_intent`) expects regular JSON input
- Bedrock Agent Core Gateway sends **MCP Protocol** requests (JSON-RPC 2.0 format)
- Your Lambda doesn't understand MCP protocol → Returns error

---

## 🔄 **The Solution: MCP Wrapper Pattern**

### **New Architecture:**
```
Bedrock Gateway → MCP Wrapper Lambda → Your Original Lambda → Response
     ↓                    ↓                      ↓              ↓
MCP Request        Translates MCP         Regular JSON     Regular JSON
(JSON-RPC 2.0)    to Regular JSON        Request         Response
     ↓                    ↓                      ↓              ↓
tools/list         Calls your Lambda      {asset_id:       {application:
tools/call         with proper format     "a208194"}       "details..."}
```

---

## 📋 **MCP Protocol Basics**

### **What is MCP (Model Context Protocol)?**
- **Purpose**: Standardized way for AI agents to discover and call tools
- **Format**: JSON-RPC 2.0 protocol
- **Methods**: 
  - `tools/list` - Discover available tools
  - `tools/call` - Execute a specific tool

### **Example MCP Requests:**

#### **1. Tools Discovery (tools/list):**
```json
{
  "jsonrpc": "2.0",
  "id": "discovery-request",
  "method": "tools/list",
  "params": {}
}
```

**Expected Response:**
```json
{
  "jsonrpc": "2.0",
  "id": "discovery-request",
  "result": {
    "tools": [
      {
        "name": "get_application_details",
        "description": "Get application details for asset ID",
        "inputSchema": {
          "type": "object",
          "properties": {
            "asset_id": {"type": "string"}
          },
          "required": ["asset_id"]
        }
      }
    ]
  }
}
```

#### **2. Tool Execution (tools/call):**
```json
{
  "jsonrpc": "2.0",
  "id": "tool-execution",
  "method": "tools/call",
  "params": {
    "name": "get_application_details",
    "arguments": {
      "asset_id": "a208194"
    }
  }
}
```

**Expected Response:**
```json
{
  "jsonrpc": "2.0",
  "id": "tool-execution",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"application_name\": \"MyApp\", \"contact\": \"admin@example.com\"}"
      }
    ]
  }
}
```

---

## 🧩 **How MCP Wrapper Lambda Works**

### **Step-by-Step Flow:**

#### **Step 1: Receive MCP Request**
```python
def lambda_handler(event, context):
    # Gateway sends MCP request to wrapper
    # event = {
    #   "jsonrpc": "2.0",
    #   "method": "tools/call",
    #   "params": {"name": "get_application_details", "arguments": {"asset_id": "a208194"}}
    # }
```

#### **Step 2: Parse MCP Request**
```python
    method = event.get('method', '')  # "tools/call"
    params = event.get('params', {})  # {"name": "get_application_details", "arguments": {...}}
    request_id = event.get('id')      # For response correlation
```

#### **Step 3: Handle MCP Methods**

##### **A. tools/list - Return Available Tools:**
```python
    if method == 'tools/list':
        return {
            "jsonrpc": "2.0",
            "id": request_id,
            "result": {
                "tools": [
                    {
                        "name": "get_application_details",
                        "description": "Get application details for asset ID",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "asset_id": {"type": "string"}
                            },
                            "required": ["asset_id"]
                        }
                    }
                ]
            }
        }
```

##### **B. tools/call - Execute Tool:**
```python
    elif method == 'tools/call':
        tool_name = params.get('name')           # "get_application_details"
        tool_arguments = params.get('arguments') # {"asset_id": "a208194"}
        
        if tool_name == 'get_application_details':
            # Call your original Lambda function
            lambda_client = boto3.client('lambda')
            
            response = lambda_client.invoke(
                FunctionName='a208194-chatops_application_details_intent',
                InvocationType='RequestResponse',
                Payload=json.dumps(tool_arguments)  # {"asset_id": "a208194"}
            )
            
            # Get response from your Lambda
            result = json.loads(response['Payload'].read())
            
            # Convert to MCP format
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "content": [
                        {
                            "type": "text",
                            "text": json.dumps(result, indent=2)
                        }
                    ]
                }
            }
```

---

## 🔍 **Detailed Code Analysis**

### **Key Components of the Wrapper:**

#### **1. Input Processing:**
```python
# Handle different event formats (API Gateway vs Direct)
if 'body' in event:
    # API Gateway format - body is string
    request_body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
else:
    # Direct invocation - event is the request
    request_body = event
```

#### **2. Lambda Client Setup:**
```python
import boto3
lambda_client = boto3.client('lambda')

# Target function ARN
TARGET_LAMBDA_ARN = "arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"
```

#### **3. Tool Registry:**
```python
# Define what tools are available
tools_registry = [
    {
        "name": "get_application_details",
        "description": "Get application details including name, contact, and regional presence for a given asset ID",
        "inputSchema": {
            "type": "object",
            "properties": {
                "asset_id": {
                    "type": "string",
                    "description": "The application asset ID (can include 'a' prefix, e.g., 'a12345' or '12345')"
                }
            },
            "required": ["asset_id"]
        }
    }
]
```

#### **4. Error Handling:**
```python
try:
    # Invoke target Lambda
    target_response = lambda_client.invoke(
        FunctionName=TARGET_LAMBDA_ARN,
        InvocationType='RequestResponse',
        Payload=json.dumps(tool_arguments)
    )
    target_result = json.loads(target_response['Payload'].read())
    
except Exception as e:
    # Return MCP-formatted error
    return {
        "jsonrpc": "2.0",
        "id": request_id,
        "error": {
            "code": -32603,
            "message": f"Internal error calling target Lambda: {str(e)}"
        }
    }
```

---

## 🧪 **Testing the Wrapper**

### **Test 1: Direct Lambda Test**
```bash
# Test the wrapper directly
aws lambda invoke \
  --function-name mcp-wrapper-lambda \
  --payload '{"jsonrpc":"2.0","id":"test","method":"tools/list","params":{}}' \
  response.json

cat response.json
```

**Expected Output:**
```json
{
  "jsonrpc": "2.0",
  "id": "test",
  "result": {
    "tools": [
      {
        "name": "get_application_details",
        "description": "...",
        "inputSchema": {...}
      }
    ]
  }
}
```

### **Test 2: Gateway Integration Test**
```python
import boto3
import requests
from botocore.auth import SigV4Auth

# Test through gateway
gateway_url = "https://your-gateway.gateway.bedrock-agentcore.us-east-1.amazonaws.com/mcp"

payload = {
    "jsonrpc": "2.0",
    "id": "gateway-test",
    "method": "tools/call",
    "params": {
        "name": "get_application_details",
        "arguments": {"asset_id": "a208194"}
    }
}

# Sign and send request...
```

---

## 🎯 **Benefits of the Wrapper Pattern**

### **1. Protocol Translation:**
- **Input**: MCP JSON-RPC → Regular JSON
- **Output**: Regular JSON → MCP JSON-RPC
- **Benefit**: No need to modify existing Lambda

### **2. Tool Discovery:**
- Bedrock agents can discover available tools via `tools/list`
- Self-documenting API with schema information

### **3. Standardization:**
- Consistent MCP protocol across all tools
- Agent compatibility with Bedrock ecosystem

### **4. Error Handling:**
- Proper MCP error format
- Detailed error messages for debugging

### **5. Extensibility:**
- Easy to add more tools/functions
- Centralized tool registry

---

## 🔧 **Configuration Flow**

### **Before (Broken):**
```
Gateway Config:
  target-lambda-arn: arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent
  
Flow:
  Gateway → Direct Lambda → UnknownOperationException
```

### **After (Working):**
```
Gateway Config:
  target-lambda-arn: arn:aws:lambda:us-east-1:818565325759:function:mcp-wrapper-lambda
  
Flow:
  Gateway → MCP Wrapper → Original Lambda → Proper Response
```

---

## 📊 **Performance Considerations**

### **Latency:**
- **Additional Hop**: Gateway → Wrapper → Target (adds ~100ms)
- **Trade-off**: Slight latency for protocol compatibility

### **Cost:**
- **Extra Lambda**: Additional invocation costs
- **Minimal**: Usually negligible compared to benefits

### **Reliability:**
- **Single Point of Failure**: Wrapper must be reliable
- **Mitigation**: Proper error handling and monitoring

---

## 🎉 **Summary**

The MCP Wrapper Lambda is essentially a **protocol translator** that:

1. **Receives** MCP-formatted requests from Bedrock Gateway
2. **Translates** them to regular JSON for your existing Lambda
3. **Invokes** your original Lambda function
4. **Converts** the response back to MCP format
5. **Returns** properly formatted MCP responses to the gateway

This allows your existing Lambda function to work seamlessly with Bedrock's Agent Core Gateway without any modifications to your original code!

The wrapper acts as a "universal adapter" that makes any Lambda function compatible with the MCP protocol used by Bedrock agents.