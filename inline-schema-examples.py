# Inline Schema Examples for MCP and Agent Core Gateway
# Complete guide for defining JSON schemas inline

## 1. MCP Tool Input Schemas (Lambda Function)
## ============================================

# Basic inline schema for simple calculator operations
def get_add_tool_schema():
    return {
        "name": "add",
        "description": "Add two numbers together",
        "inputSchema": {
            "type": "object",
            "properties": {
                "a": {
                    "type": "number", 
                    "description": "First number to add",
                    "minimum": -1000000,
                    "maximum": 1000000
                },
                "b": {
                    "type": "number", 
                    "description": "Second number to add",
                    "minimum": -1000000,
                    "maximum": 1000000
                }
            },
            "required": ["a", "b"],
            "additionalProperties": False
        }
    }

# Complex inline schema with multiple data types
def get_advanced_calculator_schema():
    return {
        "name": "calculate",
        "description": "Perform complex mathematical operations",
        "inputSchema": {
            "type": "object",
            "properties": {
                "operation": {
                    "type": "string",
                    "enum": ["add", "subtract", "multiply", "divide", "power", "sqrt", "factorial"],
                    "description": "Mathematical operation to perform"
                },
                "numbers": {
                    "type": "array",
                    "items": {
                        "type": "number"
                    },
                    "minItems": 1,
                    "maxItems": 10,
                    "description": "Array of numbers for the operation"
                },
                "precision": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 10,
                    "default": 2,
                    "description": "Number of decimal places in result"
                },
                "options": {
                    "type": "object",
                    "properties": {
                        "roundResult": {
                            "type": "boolean",
                            "default": True,
                            "description": "Whether to round the result"
                        },
                        "returnAsString": {
                            "type": "boolean", 
                            "default": False,
                            "description": "Return result as string instead of number"
                        }
                    },
                    "additionalProperties": False
                }
            },
            "required": ["operation", "numbers"],
            "additionalProperties": False
        }
    }

## 2. Application Details Tool Schema (Your Use Case)
## =================================================

def get_application_details_schema():
    return {
        "name": "get_application_details",
        "description": "Retrieve detailed information about ChatOps applications",
        "inputSchema": {
            "type": "object",
            "properties": {
                "application_name": {
                    "type": "string",
                    "pattern": "^[a-zA-Z0-9_-]+$",
                    "minLength": 1,
                    "maxLength": 100,
                    "description": "Name of the application to query"
                },
                "environment": {
                    "type": "string",
                    "enum": ["dev", "staging", "prod", "test"],
                    "description": "Environment to query (optional)",
                    "default": "prod"
                },
                "include_details": {
                    "type": "array",
                    "items": {
                        "type": "string",
                        "enum": ["config", "status", "metrics", "logs", "dependencies"]
                    },
                    "uniqueItems": True,
                    "description": "Specific details to include in response"
                },
                "format": {
                    "type": "string",
                    "enum": ["json", "text", "summary"],
                    "default": "json",
                    "description": "Response format preference"
                }
            },
            "required": ["application_name"],
            "additionalProperties": False
        }
    }

## 3. DNS Route Tool Schema
## =========================

def get_dns_route_schema():
    return {
        "name": "manage_dns_route",
        "description": "Manage DNS routing configurations",
        "inputSchema": {
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["create", "update", "delete", "query"],
                    "description": "Action to perform on DNS route"
                },
                "domain": {
                    "type": "string",
                    "pattern": "^[a-zA-Z0-9.-]+$",
                    "description": "Domain name for the route"
                },
                "record_type": {
                    "type": "string",
                    "enum": ["A", "AAAA", "CNAME", "MX", "TXT"],
                    "description": "DNS record type"
                },
                "target": {
                    "type": "string",
                    "description": "Target IP address or hostname"
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
                    "description": "Priority for MX records (optional)"
                }
            },
            "required": ["action", "domain"],
            "conditionalRequired": {
                "if": {
                    "properties": {
                        "action": {"enum": ["create", "update"]}
                    }
                },
                "then": {
                    "required": ["record_type", "target"]
                }
            },
            "additionalProperties": False
        }
    }

## 4. Validation Schema with Complex Conditions
## =============================================

def get_chatops_command_schema():
    return {
        "name": "execute_chatops_command",
        "description": "Execute ChatOps commands with validation",
        "inputSchema": {
            "type": "object",
            "properties": {
                "command": {
                    "type": "string",
                    "enum": ["deploy", "rollback", "scale", "status", "logs"],
                    "description": "ChatOps command to execute"
                },
                "application": {
                    "type": "string",
                    "pattern": "^[a-zA-Z0-9_-]+$",
                    "description": "Target application name"
                },
                "environment": {
                    "type": "string",
                    "enum": ["dev", "staging", "prod"],
                    "description": "Target environment"
                },
                "parameters": {
                    "type": "object",
                    "oneOf": [
                        {
                            "title": "Deploy Parameters",
                            "properties": {
                                "version": {
                                    "type": "string",
                                    "pattern": "^v?\\d+\\.\\d+\\.\\d+(-[a-zA-Z0-9.-]+)?$"
                                },
                                "branch": {
                                    "type": "string",
                                    "default": "main"
                                }
                            },
                            "required": ["version"]
                        },
                        {
                            "title": "Scale Parameters", 
                            "properties": {
                                "replicas": {
                                    "type": "integer",
                                    "minimum": 1,
                                    "maximum": 50
                                },
                                "cpu": {
                                    "type": "string",
                                    "pattern": "^\\d+m?$"
                                },
                                "memory": {
                                    "type": "string", 
                                    "pattern": "^\\d+(Mi|Gi)$"
                                }
                            },
                            "required": ["replicas"]
                        }
                    ]
                },
                "dry_run": {
                    "type": "boolean",
                    "default": False,
                    "description": "Execute in dry-run mode"
                },
                "confirmation": {
                    "type": "boolean",
                    "description": "User confirmation for destructive operations"
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
                        "required": ["confirmation"]
                    }
                }
            ],
            "additionalProperties": False
        }
    }

## 5. Complete MCP Lambda Function with Inline Schemas
## ===================================================

def handle_tools_list_with_inline_schemas():
    """Return all tools with comprehensive inline schemas"""
    
    return {
        "tools": [
            # Simple calculator tool
            {
                "name": "add",
                "description": "Add two numbers with validation",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "a": {
                            "type": "number",
                            "description": "First number",
                            "minimum": -999999,
                            "maximum": 999999
                        },
                        "b": {
                            "type": "number", 
                            "description": "Second number",
                            "minimum": -999999,
                            "maximum": 999999
                        }
                    },
                    "required": ["a", "b"],
                    "additionalProperties": False
                }
            },
            
            # Application details tool
            {
                "name": "get_application_details",
                "description": "Get ChatOps application information",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "app_name": {
                            "type": "string",
                            "pattern": "^[a-zA-Z0-9_-]{1,50}$",
                            "description": "Application name"
                        },
                        "env": {
                            "type": "string", 
                            "enum": ["dev", "staging", "prod"],
                            "default": "prod",
                            "description": "Environment"
                        },
                        "details": {
                            "type": "array",
                            "items": {
                                "type": "string",
                                "enum": ["config", "status", "logs", "metrics"]
                            },
                            "uniqueItems": True,
                            "minItems": 1,
                            "description": "Details to retrieve"
                        }
                    },
                    "required": ["app_name"],
                    "additionalProperties": False
                }
            },
            
            # DNS route management tool
            {
                "name": "manage_dns",
                "description": "Manage DNS route configurations",
                "inputSchema": {
                    "type": "object", 
                    "properties": {
                        "action": {
                            "type": "string",
                            "enum": ["create", "update", "delete", "list"],
                            "description": "DNS action to perform"
                        },
                        "domain": {
                            "type": "string",
                            "format": "hostname",
                            "description": "Domain name"
                        },
                        "record": {
                            "type": "object",
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "enum": ["A", "CNAME", "MX", "TXT"]
                                },
                                "value": {
                                    "type": "string",
                                    "description": "Record value"
                                },
                                "ttl": {
                                    "type": "integer",
                                    "minimum": 60,
                                    "maximum": 86400,
                                    "default": 300
                                }
                            },
                            "required": ["type", "value"],
                            "additionalProperties": False
                        }
                    },
                    "required": ["action", "domain"],
                    "if": {
                        "properties": {
                            "action": {"enum": ["create", "update"]}
                        }
                    },
                    "then": {
                        "required": ["record"]
                    },
                    "additionalProperties": False
                }
            }
        ]
    }

## 6. JSON Schema Validation Patterns
## ==================================

# Email validation
EMAIL_SCHEMA = {
    "type": "string",
    "format": "email",
    "pattern": "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
}

# URL validation  
URL_SCHEMA = {
    "type": "string",
    "format": "uri",
    "pattern": "^https?://[^\\s/$.?#].[^\\s]*$"
}

# Version validation
VERSION_SCHEMA = {
    "type": "string",
    "pattern": "^v?\\d+\\.\\d+\\.\\d+(-[a-zA-Z0-9.-]+)?$",
    "examples": ["1.0.0", "v2.1.3", "1.0.0-beta.1"]
}

# Application name validation
APP_NAME_SCHEMA = {
    "type": "string",
    "pattern": "^[a-zA-Z0-9_-]+$",
    "minLength": 1,
    "maxLength": 50,
    "description": "Alphanumeric with hyphens and underscores only"
}

# Environment validation
ENVIRONMENT_SCHEMA = {
    "type": "string",
    "enum": ["dev", "development", "test", "staging", "prod", "production"],
    "description": "Deployment environment"
}

## 7. Gateway-Compatible Schema Format
## ===================================

# This is the EXACT format Agent Core Gateway expects
GATEWAY_COMPATIBLE_TOOL = {
    "name": "your_tool_name",
    "description": "Clear description of what the tool does",
    "inputSchema": {
        "type": "object",
        "properties": {
            "param1": {
                "type": "string",
                "description": "Parameter description"
            },
            "param2": {
                "type": "number",
                "minimum": 0,
                "maximum": 100,
                "description": "Numeric parameter with constraints"
            }
        },
        "required": ["param1"],
        "additionalProperties": False
    }
}

# CRITICAL: All strings must use double quotes for JSON compatibility
# CRITICAL: No Python-specific syntax (True/False -> true/false)
# CRITICAL: All schema objects must be JSON serializable