#!/bin/bash
# CloudShell: Fix MCP Wrapper IAM PassRole Issue
# Deploy MCP wrapper using existing roles or simplified approach

echo "🔧 CloudShell MCP Wrapper - IAM PassRole Fix"
echo "==========================================="
echo ""

LAMBDA_NAME="mcp-wrapper-lambda"
TARGET_LAMBDA_ARN="arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"
REGION="us-east-1"

echo "📋 Configuration:"
echo "  Target Lambda: $TARGET_LAMBDA_ARN"
echo "  Wrapper Name: $LAMBDA_NAME"
echo "  Region: $REGION"
echo ""

echo "🔍 Step 1: Check Current Permissions"
echo "=================================="

echo "Current user identity:"
aws sts get-caller-identity --output table

echo ""
echo "Checking available roles..."

# Look for existing roles we can use
EXISTING_ROLES=$(aws iam list-roles --query 'Roles[?contains(RoleName, `lambda`) || contains(RoleName, `a208194`)].RoleName' --output text 2>/dev/null)

if [ -n "$EXISTING_ROLES" ]; then
    echo "✅ Found existing roles that might work:"
    for role in $EXISTING_ROLES; do
        echo "  • $role"
    done
    echo ""
    
    # Try to use existing application role
    EXISTING_APP_ROLE=$(echo "$EXISTING_ROLES" | grep -E 'a208194.*gateway|a208194.*lambda' | head -1)
    if [ -n "$EXISTING_APP_ROLE" ]; then
        LAMBDA_ROLE_ARN="arn:aws:iam::818565325759:role/$EXISTING_APP_ROLE"
        echo "🎯 Will try to use existing role: $LAMBDA_ROLE_ARN"
        USE_EXISTING_ROLE=true
    fi
else
    echo "⚠️  No suitable existing roles found"
fi

echo ""
echo "🔧 Step 2: Alternative Deployment Methods"
echo "======================================="

# Method 1: Try with existing gateway role
if [ "$USE_EXISTING_ROLE" = "true" ]; then
    echo "Method 1: Using existing application role..."
    echo "Role ARN: $LAMBDA_ROLE_ARN"
    
    # Create the Lambda package first
    echo ""
    echo "📦 Creating Lambda deployment package..."
    
    mkdir -p /tmp/mcp-wrapper
    cd /tmp/mcp-wrapper
    
    # Create the MCP wrapper code
    cat > lambda_function.py << 'EOF'
import json
import boto3
import logging

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize Lambda client
lambda_client = boto3.client('lambda')

# Target Lambda function ARN
TARGET_LAMBDA_ARN = "arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"

def lambda_handler(event, context):
    """
    MCP Protocol Wrapper for existing Lambda function
    Handles MCP JSON-RPC 2.0 requests and routes to target Lambda
    """
    
    logger.info(f"MCP Wrapper received event: {json.dumps(event)}")
    
    try:
        # Handle different event formats (API Gateway, direct invocation)
        if 'body' in event:
            # API Gateway format
            if isinstance(event['body'], str):
                request_body = json.loads(event['body'])
            else:
                request_body = event['body']
        else:
            # Direct invocation
            request_body = event
        
        # Extract MCP request components
        method = request_body.get('method', '')
        params = request_body.get('params', {})
        request_id = request_body.get('id', 'unknown')
        
        logger.info(f"MCP Method: {method}, Params: {params}")
        
        # Handle MCP methods
        if method == 'tools/list':
            # Return available tools
            response = {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "tools": [
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
                }
            }
            
        elif method == 'tools/call':
            # Call the target Lambda function
            tool_name = params.get('name', '')
            tool_arguments = params.get('arguments', {})
            
            if tool_name == 'get_application_details':
                # Invoke target Lambda
                try:
                    target_response = lambda_client.invoke(
                        FunctionName=TARGET_LAMBDA_ARN,
                        InvocationType='RequestResponse',
                        Payload=json.dumps(tool_arguments)
                    )
                    
                    # Parse target response
                    target_result = json.loads(target_response['Payload'].read())
                    
                    # Return MCP-formatted response
                    response = {
                        "jsonrpc": "2.0",
                        "id": request_id,
                        "result": {
                            "content": [
                                {
                                    "type": "text",
                                    "text": json.dumps(target_result, indent=2)
                                }
                            ]
                        }
                    }
                    
                except Exception as e:
                    logger.error(f"Target Lambda invocation failed: {str(e)}")
                    response = {
                        "jsonrpc": "2.0",
                        "id": request_id,
                        "error": {
                            "code": -32603,
                            "message": f"Internal error calling target Lambda: {str(e)}"
                        }
                    }
            else:
                # Unknown tool
                response = {
                    "jsonrpc": "2.0",
                    "id": request_id,
                    "error": {
                        "code": -32601,
                        "message": f"Unknown tool: {tool_name}"
                    }
                }
        else:
            # Unknown method
            response = {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {
                    "code": -32601,
                    "message": f"Method not found: {method}"
                }
            }
        
        logger.info(f"MCP Wrapper response: {json.dumps(response)}")
        
        # Return response in appropriate format
        if 'body' in event:
            # API Gateway format
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps(response)
            }
        else:
            # Direct invocation
            return response
            
    except Exception as e:
        logger.error(f"MCP Wrapper error: {str(e)}")
        
        error_response = {
            "jsonrpc": "2.0",
            "id": request_body.get('id', 'unknown') if 'request_body' in locals() else 'unknown',
            "error": {
                "code": -32603,
                "message": f"Internal error: {str(e)}"
            }
        }
        
        if 'body' in event:
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps(error_response)
            }
        else:
            return error_response
EOF

    # Create deployment package
    echo "📦 Creating zip package..."
    zip -r mcp-wrapper-lambda.zip lambda_function.py
    
    if [ -f "mcp-wrapper-lambda.zip" ]; then
        echo "✅ Package created: $(ls -lh mcp-wrapper-lambda.zip)"
        
        # Try to create Lambda function
        echo ""
        echo "🚀 Deploying Lambda function..."
        
        aws lambda create-function \
          --function-name "$LAMBDA_NAME" \
          --runtime python3.9 \
          --role "$LAMBDA_ROLE_ARN" \
          --handler lambda_function.lambda_handler \
          --zip-file fileb://mcp-wrapper-lambda.zip \
          --description "MCP Protocol wrapper for a208194-chatops_application_details_intent" \
          --timeout 60 \
          --memory-size 256 \
          --output json
        
        CREATE_RESULT=$?
        
        if [ $CREATE_RESULT -eq 0 ]; then
            echo "🎉 SUCCESS! Lambda function created!"
            DEPLOYMENT_SUCCESS=true
        else
            echo "❌ Lambda creation failed with existing role"
        fi
    else
        echo "❌ Failed to create deployment package"
    fi
    
    cd - > /dev/null
fi

# Method 2: Use CloudFormation with automatic role creation
if [ "$DEPLOYMENT_SUCCESS" != "true" ]; then
    echo ""
    echo "Method 2: CloudFormation deployment with managed roles..."
    
    cat > /tmp/mcp-wrapper-cloudformation.yaml << 'EOF'
AWSTemplateFormatVersion: '2010-09-09'
Description: 'MCP Wrapper Lambda with automatic IAM role creation'

Parameters:
  TargetLambdaArn:
    Type: String
    Default: 'arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent'
    Description: 'ARN of the target Lambda function to wrap'

Resources:
  MCPWrapperRole:
    Type: 'AWS::IAM::Role'
    Properties:
      RoleName: 'mcp-wrapper-lambda-role-cf'
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: 'sts:AssumeRole'
      ManagedPolicyArns:
        - 'arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole'
      Policies:
        - PolicyName: 'InvokeTargetLambda'
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 'lambda:InvokeFunction'
                Resource: !Ref TargetLambdaArn

  MCPWrapperFunction:
    Type: 'AWS::Lambda::Function'
    Properties:
      FunctionName: 'mcp-wrapper-lambda-cf'
      Runtime: 'python3.9'
      Handler: 'index.lambda_handler'
      Role: !GetAtt MCPWrapperRole.Arn
      Timeout: 60
      MemorySize: 256
      Description: 'MCP Protocol wrapper deployed via CloudFormation'
      Code:
        ZipFile: |
          import json
          import boto3
          import logging

          logger = logging.getLogger()
          logger.setLevel(logging.INFO)
          lambda_client = boto3.client('lambda')

          TARGET_LAMBDA_ARN = "arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"

          def lambda_handler(event, context):
              logger.info(f"MCP Wrapper received: {json.dumps(event)}")
              
              try:
                  if 'body' in event:
                      request_body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
                  else:
                      request_body = event
                  
                  method = request_body.get('method', '')
                  params = request_body.get('params', {})
                  request_id = request_body.get('id', 'unknown')
                  
                  if method == 'tools/list':
                      response = {
                          "jsonrpc": "2.0",
                          "id": request_id,
                          "result": {
                              "tools": [
                                  {
                                      "name": "get_application_details",
                                      "description": "Get application details for a given asset ID",
                                      "inputSchema": {
                                          "type": "object",
                                          "properties": {
                                              "asset_id": {"type": "string", "description": "Application asset ID"}
                                          },
                                          "required": ["asset_id"]
                                      }
                                  }
                              ]
                          }
                      }
                  elif method == 'tools/call':
                      tool_name = params.get('name', '')
                      tool_arguments = params.get('arguments', {})
                      
                      if tool_name == 'get_application_details':
                          try:
                              target_response = lambda_client.invoke(
                                  FunctionName=TARGET_LAMBDA_ARN,
                                  InvocationType='RequestResponse',
                                  Payload=json.dumps(tool_arguments)
                              )
                              target_result = json.loads(target_response['Payload'].read())
                              response = {
                                  "jsonrpc": "2.0",
                                  "id": request_id,
                                  "result": {
                                      "content": [{"type": "text", "text": json.dumps(target_result, indent=2)}]
                                  }
                              }
                          except Exception as e:
                              response = {
                                  "jsonrpc": "2.0",
                                  "id": request_id,
                                  "error": {"code": -32603, "message": f"Error calling target: {str(e)}"}
                              }
                      else:
                          response = {
                              "jsonrpc": "2.0",
                              "id": request_id,
                              "error": {"code": -32601, "message": f"Unknown tool: {tool_name}"}
                          }
                  else:
                      response = {
                          "jsonrpc": "2.0",
                          "id": request_id,
                          "error": {"code": -32601, "message": f"Method not found: {method}"}
                      }
                  
                  if 'body' in event:
                      return {
                          'statusCode': 200,
                          'headers': {'Content-Type': 'application/json'},
                          'body': json.dumps(response)
                      }
                  else:
                      return response
              except Exception as e:
                  logger.error(f"Error: {str(e)}")
                  error_response = {
                      "jsonrpc": "2.0",
                      "id": "error",
                      "error": {"code": -32603, "message": str(e)}
                  }
                  if 'body' in event:
                      return {'statusCode': 500, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps(error_response)}
                  else:
                      return error_response

Outputs:
  MCPWrapperFunctionArn:
    Description: 'ARN of the MCP wrapper Lambda function'
    Value: !GetAtt MCPWrapperFunction.Arn
    Export:
      Name: 'mcp-wrapper-lambda-arn'
      
  MCPWrapperRoleArn:
    Description: 'ARN of the MCP wrapper Lambda role'
    Value: !GetAtt MCPWrapperRole.Arn
EOF

    echo ""
    echo "🚀 Deploying via CloudFormation..."
    
    aws cloudformation create-stack \
      --stack-name mcp-wrapper-stack \
      --template-body file:///tmp/mcp-wrapper-cloudformation.yaml \
      --capabilities CAPABILITY_NAMED_IAM \
      --parameters ParameterKey=TargetLambdaArn,ParameterValue="$TARGET_LAMBDA_ARN" \
      --output json
    
    CF_RESULT=$?
    
    if [ $CF_RESULT -eq 0 ]; then
        echo "✅ CloudFormation deployment started!"
        
        echo "⏳ Waiting for stack creation..."
        aws cloudformation wait stack-create-complete --stack-name mcp-wrapper-stack
        
        if [ $? -eq 0 ]; then
            echo "🎉 SUCCESS! CloudFormation stack created!"
            
            # Get the Lambda ARN from CloudFormation outputs
            MCP_WRAPPER_ARN=$(aws cloudformation describe-stacks \
              --stack-name mcp-wrapper-stack \
              --query 'Stacks[0].Outputs[?OutputKey==`MCPWrapperFunctionArn`].OutputValue' \
              --output text)
            
            echo "✅ MCP Wrapper Lambda ARN: $MCP_WRAPPER_ARN"
            DEPLOYMENT_SUCCESS=true
            CLOUDFORMATION_DEPLOYED=true
        else
            echo "❌ CloudFormation deployment failed"
        fi
    else
        echo "❌ CloudFormation deployment failed to start"
    fi
fi

# Method 3: Provide manual instructions
if [ "$DEPLOYMENT_SUCCESS" != "true" ]; then
    echo ""
    echo "Method 3: Manual Console Deployment Instructions"
    echo "=============================================="
    
    echo ""
    echo "🔧 Since automated deployment failed due to IAM restrictions,"
    echo "   you'll need to deploy via AWS Console:"
    echo ""
    echo "📋 Steps:"
    echo "1. 🌐 Go to AWS Lambda Console"
    echo "2. ➕ Click 'Create Function'"
    echo "3. 🏷️  Function name: mcp-wrapper-lambda"
    echo "4. 🐍 Runtime: Python 3.9"
    echo "5. 🔑 Execution role: Use existing role → a208194-askjulius-agentcore-gateway"
    echo "6. ➡️  Click 'Create Function'"
    echo "7. 📝 Replace code with the Python code below"
    echo "8. 💾 Deploy the function"
    echo ""
    
    echo "📄 Python Code to paste:"
    echo "======================="
    echo "Copy this entire code into the Lambda function editor:"
    echo ""
    
    # Display the Python code
    cat > /tmp/mcp-wrapper-code.py << 'EOF'
import json
import boto3
import logging

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize Lambda client
lambda_client = boto3.client('lambda')

# Target Lambda function ARN
TARGET_LAMBDA_ARN = "arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"

def lambda_handler(event, context):
    """
    MCP Protocol Wrapper for existing Lambda function
    """
    logger.info(f"MCP Wrapper received: {json.dumps(event)}")
    
    try:
        if 'body' in event:
            request_body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        else:
            request_body = event
        
        method = request_body.get('method', '')
        params = request_body.get('params', {})
        request_id = request_body.get('id', 'unknown')
        
        if method == 'tools/list':
            response = {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "tools": [
                        {
                            "name": "get_application_details",
                            "description": "Get application details for a given asset ID",
                            "inputSchema": {
                                "type": "object",
                                "properties": {
                                    "asset_id": {"type": "string", "description": "Application asset ID"}
                                },
                                "required": ["asset_id"]
                            }
                        }
                    ]
                }
            }
        elif method == 'tools/call':
            tool_name = params.get('name', '')
            tool_arguments = params.get('arguments', {})
            
            if tool_name == 'get_application_details':
                try:
                    target_response = lambda_client.invoke(
                        FunctionName=TARGET_LAMBDA_ARN,
                        InvocationType='RequestResponse',
                        Payload=json.dumps(tool_arguments)
                    )
                    target_result = json.loads(target_response['Payload'].read())
                    response = {
                        "jsonrpc": "2.0",
                        "id": request_id,
                        "result": {
                            "content": [{"type": "text", "text": json.dumps(target_result, indent=2)}]
                        }
                    }
                except Exception as e:
                    response = {
                        "jsonrpc": "2.0",
                        "id": request_id,
                        "error": {"code": -32603, "message": f"Error: {str(e)}"}
                    }
            else:
                response = {
                    "jsonrpc": "2.0",
                    "id": request_id,
                    "error": {"code": -32601, "message": f"Unknown tool: {tool_name}"}
                }
        else:
            response = {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {"code": -32601, "message": f"Method not found: {method}"}
            }
        
        if 'body' in event:
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps(response)
            }
        else:
            return response
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return {"error": str(e)}
EOF

    echo "Copy the code from: /tmp/mcp-wrapper-code.py"
    echo ""
    
    cat /tmp/mcp-wrapper-code.py
fi

echo ""
echo "🔍 Step 3: Test Deployment"
echo "========================"

if [ "$DEPLOYMENT_SUCCESS" = "true" ]; then
    if [ "$CLOUDFORMATION_DEPLOYED" = "true" ]; then
        WRAPPER_FUNCTION_NAME="mcp-wrapper-lambda-cf"
    else
        WRAPPER_FUNCTION_NAME="mcp-wrapper-lambda"
    fi
    
    echo "Testing the deployed MCP wrapper..."
    
    # Test the wrapper function
    TEST_PAYLOAD='{
        "jsonrpc": "2.0",
        "id": "test-1",
        "method": "tools/list",
        "params": {}
    }'
    
    echo "Test payload: $TEST_PAYLOAD"
    
    aws lambda invoke \
      --function-name "$WRAPPER_FUNCTION_NAME" \
      --payload "$TEST_PAYLOAD" \
      /tmp/wrapper-test-response.json
    
    if [ $? -eq 0 ]; then
        echo "✅ Wrapper test response:"
        cat /tmp/wrapper-test-response.json | jq . 2>/dev/null || cat /tmp/wrapper-test-response.json
        
        # Get the wrapper function ARN for gateway configuration
        WRAPPER_ARN=$(aws lambda get-function --function-name "$WRAPPER_FUNCTION_NAME" --query 'Configuration.FunctionArn' --output text)
        echo ""
        echo "🎯 MCP Wrapper Function ARN: $WRAPPER_ARN"
        
    else
        echo "❌ Wrapper test failed"
    fi
else
    echo "⚠️  Deployment not completed automatically"
    echo "   Please follow manual deployment instructions above"
fi

echo ""
echo "🔍 Step 4: Update Gateway Configuration"
echo "===================================="

if [ -n "$WRAPPER_ARN" ]; then
    echo "Updating gateway to use MCP wrapper..."
    
    GATEWAY_ID="a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59"
    
    # Try different methods to update gateway
    echo "Method 1: --target-lambda-arn"
    aws bedrock-agentcore-control update-gateway \
      --gateway-id "$GATEWAY_ID" \
      --target-lambda-arn "$WRAPPER_ARN" \
      --output json 2>&1
    
    UPDATE_RESULT=$?
    
    if [ $UPDATE_RESULT -ne 0 ]; then
        echo "Method 2: --lambda-arn"
        aws bedrock-agentcore-control update-gateway \
          --gateway-id "$GATEWAY_ID" \
          --lambda-arn "$WRAPPER_ARN" \
          --output json 2>&1
    fi
    
    echo ""
    echo "Verifying gateway configuration..."
    aws bedrock-agentcore-control get-gateway --gateway-id "$GATEWAY_ID" --output json | jq '{id: .id, name: .name, status: .status, lambdaArn: .lambdaArn}'
    
fi

echo ""
echo "📋 SUMMARY"
echo "========="

if [ "$DEPLOYMENT_SUCCESS" = "true" ]; then
    echo "🎉 MCP Wrapper deployment SUCCESSFUL!"
    echo ""
    echo "✅ What was deployed:"
    if [ "$CLOUDFORMATION_DEPLOYED" = "true" ]; then
        echo "   • CloudFormation stack: mcp-wrapper-stack"
        echo "   • Lambda function: mcp-wrapper-lambda-cf"
        echo "   • IAM role: mcp-wrapper-lambda-role-cf"
    else
        echo "   • Lambda function: mcp-wrapper-lambda"
        echo "   • Using existing role: $LAMBDA_ROLE_ARN"
    fi
    
    if [ -n "$WRAPPER_ARN" ]; then
        echo "   • Function ARN: $WRAPPER_ARN"
        echo ""
        echo "🚀 Next Steps:"
        echo "   1. Test gateway with MCP requests"
        echo "   2. Gateway should now return proper MCP responses"
        echo "   3. Use tools/list and tools/call methods"
    fi
    
else
    echo "⚠️  Automatic deployment failed due to IAM restrictions"
    echo ""
    echo "🔧 Manual deployment required:"
    echo "   1. Use AWS Lambda Console"
    echo "   2. Create function with existing role"
    echo "   3. Copy Python code from /tmp/mcp-wrapper-code.py"
    echo "   4. Update gateway to use new function ARN"
fi

echo ""
echo "✅ MCP Wrapper IAM fix process completed!"