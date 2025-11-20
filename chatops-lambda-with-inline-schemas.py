import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Template Lambda with Inline Schemas for Agent Core Gateway
    
    This template shows how to define inline schemas for various tool types
    """
    
    try:
        logger.info(f"Received event: {json.dumps(event, default=str)}")
        
        # Handle both API Gateway and direct invocation
        if 'body' in event:
            if isinstance(event['body'], str):
                body = json.loads(event['body'])
            else:
                body = event['body']
        else:
            body = event
            
        # Validate JSON-RPC 2.0 format
        if not isinstance(body, dict) or body.get('jsonrpc') != '2.0':
            return create_error_response(
                body.get('id') if isinstance(body, dict) else None,
                -32600,
                "Invalid Request - Must be JSON-RPC 2.0 format"
            )
        
        method = body.get('method')
        params = body.get('params', {})
        request_id = body.get('id')
        
        # Handle MCP methods
        if method == 'tools/list':
            result = get_tools_with_inline_schemas()
        elif method == 'tools/call':
            result = execute_tool(params)
        else:
            return create_error_response(request_id, -32601, f"Method not found: {method}")
        
        # Return success response
        return create_success_response(request_id, result)
        
    except Exception as e:
        logger.error(f"Lambda error: {str(e)}")
        return create_error_response(
            body.get('id') if 'body' in locals() and isinstance(body, dict) else None,
            -32603, 
            "Internal error",
            str(e)
        )

def get_tools_with_inline_schemas():
    """
    Define all tools with comprehensive inline schemas
    
    CRITICAL for Gateway Compatibility:
    - Use double quotes for ALL strings
    - Ensure JSON serializable format
    - Include proper validation rules
    """
    
    return {
        "tools": [
            # 1. Application Details Tool (ChatOps)
            {
                "name": "get_application_details",
                "description": "Retrieve detailed information about ChatOps applications including status, configuration, and metrics",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "application_name": {
                            "type": "string",
                            "pattern": "^[a-zA-Z0-9_-]{1,50}$",
                            "description": "Name of the application to query (alphanumeric, hyphens, underscores only)"
                        },
                        "environment": {
                            "type": "string",
                            "enum": ["dev", "test", "staging", "prod"],
                            "default": "prod",
                            "description": "Environment to query application details from"
                        },
                        "include_sections": {
                            "type": "array",
                            "items": {
                                "type": "string",
                                "enum": ["basic_info", "configuration", "status", "metrics", "logs", "dependencies", "recent_deployments"]
                            },
                            "uniqueItems": True,
                            "minItems": 1,
                            "description": "Specific sections to include in the response"
                        },
                        "format": {
                            "type": "string",
                            "enum": ["json", "text", "summary", "detailed"],
                            "default": "summary",
                            "description": "Response format preference"
                        },
                        "time_range": {
                            "type": "string",
                            "enum": ["1h", "24h", "7d", "30d"],
                            "default": "24h", 
                            "description": "Time range for metrics and logs"
                        }
                    },
                    "required": ["application_name"],
                    "additionalProperties": False
                }
            },
            
            # 2. DNS Route Management Tool
            {
                "name": "manage_dns_route",
                "description": "Create, update, delete, or query DNS routing configurations for applications",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "action": {
                            "type": "string",
                            "enum": ["create", "update", "delete", "query", "list"],
                            "description": "Action to perform on DNS route"
                        },
                        "domain": {
                            "type": "string",
                            "pattern": "^[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$",
                            "description": "Fully qualified domain name"
                        },
                        "subdomain": {
                            "type": "string",
                            "pattern": "^[a-zA-Z0-9-]+$",
                            "description": "Subdomain prefix (optional)"
                        },
                        "record_config": {
                            "type": "object",
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "enum": ["A", "AAAA", "CNAME", "MX", "TXT", "SRV"],
                                    "description": "DNS record type"
                                },
                                "target": {
                                    "type": "string",
                                    "description": "Target IP address, hostname, or text value"
                                },
                                "ttl": {
                                    "type": "integer",
                                    "minimum": 60,
                                    "maximum": 86400,
                                    "default": 300,
                                    "description": "Time-to-live in seconds"
                                },
                                "priority": {
                                    "type": "integer",
                                    "minimum": 0,
                                    "maximum": 65535,
                                    "description": "Priority for MX/SRV records"
                                }
                            },
                            "required": ["type", "target"],
                            "additionalProperties": False
                        },
                        "environment": {
                            "type": "string",
                            "enum": ["dev", "staging", "prod"],
                            "default": "prod",
                            "description": "Environment for DNS configuration"
                        }
                    },
                    "required": ["action", "domain"],
                    "if": {
                        "properties": {
                            "action": {"enum": ["create", "update"]}
                        }
                    },
                    "then": {
                        "required": ["record_config"]
                    },
                    "additionalProperties": False
                }
            },
            
            # 3. ChatOps Command Execution Tool
            {
                "name": "execute_chatops_command",
                "description": "Execute ChatOps deployment and management commands with proper validation and confirmation",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "command": {
                            "type": "string",
                            "enum": ["deploy", "rollback", "scale", "restart", "status", "logs", "config"],
                            "description": "ChatOps command to execute"
                        },
                        "application": {
                            "type": "string",
                            "pattern": "^[a-zA-Z0-9_-]{1,50}$",
                            "description": "Target application name"
                        },
                        "environment": {
                            "type": "string",
                            "enum": ["dev", "staging", "prod"],
                            "description": "Target environment for command execution"
                        },
                        "parameters": {
                            "type": "object",
                            "description": "Command-specific parameters",
                            "oneOf": [
                                {
                                    "title": "Deploy Parameters",
                                    "properties": {
                                        "version": {
                                            "type": "string",
                                            "pattern": "^v?\\d+\\.\\d+\\.\\d+(-[a-zA-Z0-9.-]+)?$",
                                            "description": "Version to deploy (semver format)"
                                        },
                                        "branch": {
                                            "type": "string",
                                            "default": "main",
                                            "description": "Git branch to deploy from"
                                        },
                                        "force": {
                                            "type": "boolean",
                                            "default": False,
                                            "description": "Force deployment even if checks fail"
                                        }
                                    },
                                    "required": ["version"],
                                    "additionalProperties": False
                                },
                                {
                                    "title": "Scale Parameters",
                                    "properties": {
                                        "replicas": {
                                            "type": "integer",
                                            "minimum": 1,
                                            "maximum": 50,
                                            "description": "Number of application replicas"
                                        },
                                        "cpu": {
                                            "type": "string",
                                            "pattern": "^\\d+m?$",
                                            "description": "CPU allocation (e.g., 500m, 1)"
                                        },
                                        "memory": {
                                            "type": "string",
                                            "pattern": "^\\d+(Mi|Gi)$",
                                            "description": "Memory allocation (e.g., 512Mi, 2Gi)"
                                        }
                                    },
                                    "required": ["replicas"],
                                    "additionalProperties": False
                                }
                            ]
                        },
                        "dry_run": {
                            "type": "boolean",
                            "default": False,
                            "description": "Execute in dry-run mode without making changes"
                        },
                        "confirmation": {
                            "type": "boolean",
                            "description": "User confirmation for destructive operations"
                        },
                        "notify_channels": {
                            "type": "array",
                            "items": {
                                "type": "string",
                                "enum": ["slack", "email", "teams", "webhook"]
                            },
                            "uniqueItems": True,
                            "description": "Notification channels for command results"
                        }
                    },
                    "required": ["command", "application", "environment"],
                    "allOf": [
                        {
                            "if": {
                                "properties": {
                                    "environment": {"const": "prod"}
                                }
                            },
                            "then": {
                                "required": ["confirmation"],
                                "properties": {
                                    "confirmation": {"const": True}
                                }
                            }
                        }
                    ],
                    "additionalProperties": False
                }
            },
            
            # 4. System Status Check Tool
            {
                "name": "check_system_status",
                "description": "Check the health and status of system components and services",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "service_type": {
                            "type": "string",
                            "enum": ["application", "database", "cache", "queue", "storage", "all"],
                            "default": "all",
                            "description": "Type of services to check"
                        },
                        "environment": {
                            "type": "string",
                            "enum": ["dev", "staging", "prod"],
                            "default": "prod",
                            "description": "Environment to check"
                        },
                        "include_metrics": {
                            "type": "boolean",
                            "default": True,
                            "description": "Include performance metrics in status check"
                        },
                        "depth": {
                            "type": "string",
                            "enum": ["basic", "detailed", "comprehensive"],
                            "default": "basic",
                            "description": "Level of detail in status check"
                        }
                    },
                    "additionalProperties": False
                }
            },
            
            # 5. Configuration Management Tool  
            {
                "name": "manage_configuration",
                "description": "View, update, or validate application configuration settings",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "action": {
                            "type": "string",
                            "enum": ["get", "set", "delete", "validate", "backup", "restore"],
                            "description": "Configuration action to perform"
                        },
                        "application": {
                            "type": "string",
                            "pattern": "^[a-zA-Z0-9_-]{1,50}$",
                            "description": "Target application"
                        },
                        "environment": {
                            "type": "string", 
                            "enum": ["dev", "staging", "prod"],
                            "description": "Target environment"
                        },
                        "config_key": {
                            "type": "string",
                            "pattern": "^[a-zA-Z0-9._-]+$",
                            "description": "Configuration key (dot notation supported)"
                        },
                        "config_value": {
                            "type": "string",
                            "description": "Configuration value (required for set action)"
                        },
                        "validate_only": {
                            "type": "boolean",
                            "default": False,
                            "description": "Only validate configuration without applying"
                        }
                    },
                    "required": ["action", "application", "environment"],
                    "if": {
                        "properties": {
                            "action": {"enum": ["set", "get", "delete"]}
                        }
                    },
                    "then": {
                        "required": ["config_key"]
                    },
                    "additionalProperties": False
                }
            }
        ]
    }

def execute_tool(params):
    """Execute tool based on name and arguments"""
    
    tool_name = params.get('name')
    arguments = params.get('arguments', {})
    
    logger.info(f"Executing tool: {tool_name} with arguments: {arguments}")
    
    try:
        if tool_name == "get_application_details":
            return handle_application_details(arguments)
        elif tool_name == "manage_dns_route":
            return handle_dns_route(arguments)
        elif tool_name == "execute_chatops_command":
            return handle_chatops_command(arguments)
        elif tool_name == "check_system_status":
            return handle_system_status(arguments)
        elif tool_name == "manage_configuration":
            return handle_configuration(arguments)
        else:
            raise ValueError(f"Unknown tool: {tool_name}")
            
    except Exception as e:
        logger.error(f"Tool execution error: {str(e)}")
        return {
            "content": [{
                "type": "text",
                "text": f"Tool execution failed: {str(e)}"
            }],
            "isError": True
        }

def handle_application_details(args):
    """Handle application details requests"""
    app_name = args.get('application_name')
    env = args.get('environment', 'prod')
    
    # Your application details logic here
    result_text = f"Application Details for {app_name} in {env} environment:\n"
    result_text += "Status: Running\nVersion: 1.2.3\nHealth: OK"
    
    return {
        "content": [{
            "type": "text",
            "text": result_text
        }],
        "isError": False
    }

def handle_dns_route(args):
    """Handle DNS route management"""
    action = args.get('action')
    domain = args.get('domain')
    
    result_text = f"DNS Route {action} for domain {domain}: Success"
    
    return {
        "content": [{
            "type": "text", 
            "text": result_text
        }],
        "isError": False
    }

def handle_chatops_command(args):
    """Handle ChatOps command execution"""
    command = args.get('command')
    application = args.get('application')
    environment = args.get('environment')
    
    result_text = f"ChatOps {command} executed for {application} in {environment}: Success"
    
    return {
        "content": [{
            "type": "text",
            "text": result_text
        }],
        "isError": False
    }

def handle_system_status(args):
    """Handle system status checks"""
    service_type = args.get('service_type', 'all')
    environment = args.get('environment', 'prod')
    
    result_text = f"System Status Check for {service_type} services in {environment}: All services healthy"
    
    return {
        "content": [{
            "type": "text",
            "text": result_text
        }],
        "isError": False
    }

def handle_configuration(args):
    """Handle configuration management"""
    action = args.get('action')
    application = args.get('application')
    
    result_text = f"Configuration {action} for {application}: Success"
    
    return {
        "content": [{
            "type": "text",
            "text": result_text
        }],
        "isError": False
    }

def create_success_response(request_id, result):
    """Create successful JSON-RPC response"""
    return {
        "jsonrpc": "2.0",
        "result": result,
        "id": request_id
    }

def create_error_response(request_id, code, message, data=None):
    """Create error JSON-RPC response"""
    error = {
        "code": code,
        "message": message
    }
    if data:
        error["data"] = data
        
    return {
        "jsonrpc": "2.0",
        "error": error,
        "id": request_id
    }