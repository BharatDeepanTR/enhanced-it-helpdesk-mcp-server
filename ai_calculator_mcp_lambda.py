import json
import boto3
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    """
    MCP-Compatible AI Calculator using Bedrock Claude
    This Lambda acts as an MCP server that internally calls Bedrock models
    """
    
    try:
        # Initialize Bedrock client
        bedrock_runtime = boto3.client('bedrock-runtime', region_name='us-east-1')
        
        # Handle MCP protocol
        if 'method' in event:
            method = event['method']
            request_id = event.get('id', 1)
            
            if method == "tools/list":
                # Return available AI calculator tools
                return {
                    "jsonrpc": "2.0",
                    "result": {
                        "tools": [
                            {
                                "name": "ai_calculate",
                                "description": "AI-powered calculator that can handle natural language math queries, complex calculations, and provide step-by-step explanations",
                                "inputSchema": {
                                    "type": "object",
                                    "properties": {
                                        "query": {
                                            "type": "string",
                                            "description": "Natural language math query (e.g., 'What is 15% of $50,000?', 'Calculate compound interest for 5 years at 4.5%')"
                                        }
                                    },
                                    "required": ["query"]
                                }
                            },
                            {
                                "name": "explain_calculation",
                                "description": "Explain mathematical concepts and provide step-by-step solutions for given calculations",
                                "inputSchema": {
                                    "type": "object",
                                    "properties": {
                                        "calculation": {
                                            "type": "string",
                                            "description": "Mathematical expression or problem to explain (e.g., '25 + 4', 'quadratic formula')"
                                        }
                                    },
                                    "required": ["calculation"]
                                }
                            },
                            {
                                "name": "solve_word_problem",
                                "description": "Solve mathematical word problems with detailed explanations",
                                "inputSchema": {
                                    "type": "object",
                                    "properties": {
                                        "problem": {
                                            "type": "string",
                                            "description": "Mathematical word problem to solve"
                                        }
                                    },
                                    "required": ["problem"]
                                }
                            }
                        ]
                    },
                    "id": request_id
                }
                
            elif method == "tools/call":
                # Handle tool calls
                params = event.get('params', {})
                tool_name = params.get('name', '').split('___')[-1]  # Extract tool name after target prefix
                arguments = params.get('arguments', {})
                
                if tool_name in ["ai_calculate", "explain_calculation", "solve_word_problem"]:
                    try:
                        # Get the query/calculation/problem from arguments
                        user_query = arguments.get('query') or arguments.get('calculation') or arguments.get('problem', '')
                        
                        if not user_query:
                            return {
                                "jsonrpc": "2.0",
                                "result": {
                                    "content": [
                                        {
                                            "type": "text",
                                            "text": "Error: Missing required input (query/calculation/problem)"
                                        }
                                    ],
                                    "isError": True
                                },
                                "id": request_id
                            }
                        
                        # Call Bedrock Claude model
                        ai_response = call_bedrock_claude(bedrock_runtime, user_query, tool_name)
                        
                        return {
                            "jsonrpc": "2.0",
                            "result": {
                                "content": [
                                    {
                                        "type": "text",
                                        "text": ai_response
                                    }
                                ],
                                "isError": False
                            },
                            "id": request_id
                        }
                        
                    except Exception as e:
                        return {
                            "jsonrpc": "2.0",
                            "result": {
                                "content": [
                                    {
                                        "type": "text",
                                        "text": f"AI calculation error: {str(e)}"
                                    }
                                ],
                                "isError": True
                            },
                            "id": request_id
                        }
                else:
                    return {
                        "jsonrpc": "2.0",
                        "error": {
                            "code": -32601,
                            "message": f"Unknown tool: {tool_name}"
                        },
                        "id": request_id
                    }
            else:
                return {
                    "jsonrpc": "2.0",
                    "error": {
                        "code": -32601,
                        "message": f"Unknown method: {method}"
                    },
                    "id": request_id
                }
        else:
            # Handle direct invocation (legacy support)
            query = event.get('query', '')
            if query:
                ai_response = call_bedrock_claude(bedrock_runtime, query, 'ai_calculate')
                return {
                    "statusCode": 200,
                    "body": json.dumps({"result": ai_response})
                }
            else:
                return {
                    "statusCode": 400,
                    "body": json.dumps({"error": "Missing query parameter"})
                }
                
    except Exception as e:
        print(f"Lambda error: {str(e)}")
        if 'method' in event:
            return {
                "jsonrpc": "2.0",
                "result": {
                    "content": [
                        {
                            "type": "text",
                            "text": f"Internal error: {str(e)}"
                        }
                    ],
                    "isError": True
                },
                "id": event.get('id', 1)
            }
        else:
            return {
                "statusCode": 500,
                "body": json.dumps({"error": str(e)})
            }


def call_bedrock_claude(bedrock_runtime, user_query, tool_type):
    """
    Call Bedrock Claude model for AI-powered calculations
    """
    
    # Customize system prompt based on tool type
    if tool_type == "explain_calculation":
        system_prompt = """You are an expert mathematics tutor. Your job is to explain mathematical calculations step-by-step in a clear, educational manner. Always:
1. Break down the problem into clear steps
2. Explain the mathematical concepts involved
3. Show the work clearly
4. Provide the final answer
5. Use proper mathematical notation when helpful"""
        
    elif tool_type == "solve_word_problem":
        system_prompt = """You are an expert at solving mathematical word problems. Your approach should be:
1. Identify what information is given
2. Determine what needs to be found
3. Choose the appropriate mathematical method/formula
4. Set up the problem clearly
5. Solve step-by-step with explanations
6. Verify the answer makes sense in context"""
        
    else:  # ai_calculate
        system_prompt = """You are an advanced AI calculator assistant. You can:
1. Perform any mathematical calculations (basic arithmetic, algebra, calculus, statistics, etc.)
2. Handle natural language math queries
3. Convert between units and work with percentages
4. Solve equations and provide mathematical insights
5. Show step-by-step work for complex calculations

Always provide clear, accurate calculations with explanations when helpful."""

    # Prepare the request for Claude
    try:
        # Claude 3.5 Sonnet model
        model_id = "anthropic.claude-3-5-sonnet-20241022-v2:0"
        
        # Prepare messages
        messages = [
            {
                "role": "user", 
                "content": user_query
            }
        ]
        
        # Request body
        request_body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 1000,
            "temperature": 0.1,  # Low temperature for precise calculations
            "top_p": 0.9,
            "system": system_prompt,
            "messages": messages
        }
        
        # Call Bedrock
        response = bedrock_runtime.invoke_model(
            modelId=model_id,
            body=json.dumps(request_body),
            contentType="application/json",
            accept="application/json"
        )
        
        # Parse response
        response_body = json.loads(response['body'].read())
        
        # Extract the text content
        if 'content' in response_body and len(response_body['content']) > 0:
            return response_body['content'][0]['text']
        else:
            return "Error: No response content from AI model"
            
    except ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code == 'AccessDeniedException':
            return "Error: Access denied to Bedrock model. Please check IAM permissions."
        elif error_code == 'ValidationException':
            return "Error: Invalid request to Bedrock model."
        else:
            return f"Error calling Bedrock: {str(e)}"
    except Exception as e:
        return f"Error: {str(e)}"