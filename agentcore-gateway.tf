# Terraform configuration for Bedrock Agent Core Gateway
# Note: This may require the latest AWS provider that supports Agent Core

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Note: The actual resource type may differ based on AWS provider updates
# This is a template that may need adjustment

resource "aws_bedrock_agent_core_gateway" "askjulius_gateway" {
  name                    = "a208194-askjulius-agentcore-gateway"
  semantic_search_enabled = true
  
  inbound_auth_config {
    type = "IAM_PERMISSIONS"
  }
  
  service_role = "a208194-askjulius-agentcore-gateway"
  
  target {
    name        = "a208194-application-details-tool-target"
    description = "Details of the application based on the asset insight"
    type        = "LAMBDA_ARN"
    lambda_arn  = "arn:aws:lambda:us-east-1:818565325759:function:a208194-chatops_application_details_intent"
    
    schema {
      type = "INLINE"
      content = jsonencode({
        name = "get_application_details"
        description = "Get application details including name, contact, and regional presence for a given asset ID"
        inputSchema = {
          type = "object"
          properties = {
            asset_id = {
              type = "string"
              description = "The application asset ID (can include 'a' prefix, e.g., 'a12345' or '12345')"
            }
          }
          required = ["asset_id"]
        }
      })
    }
    
    outbound_auth_config {
      type = "IAM_ROLE"
    }
  }
  
  tags = {
    Name        = "askjulius-agentcore-gateway"
    Environment = "production"
    Purpose     = "application-details-lookup"
  }
}

output "gateway_id" {
  description = "ID of the created Agent Core Gateway"
  value       = aws_bedrock_agent_core_gateway.askjulius_gateway.id
}

output "gateway_arn" {
  description = "ARN of the created Agent Core Gateway"
  value       = aws_bedrock_agent_core_gateway.askjulius_gateway.arn
}