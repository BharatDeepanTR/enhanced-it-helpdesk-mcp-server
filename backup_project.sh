#!/bin/bash

# Backup and Archive Current Project
# Enhanced IT Helpdesk MCP Server - Phase 1 Complete

echo "📦 Creating Project Backup and Archive"
echo "======================================"

PROJECT_NAME="enhanced-it-helpdesk-mcp-server"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="${PROJECT_NAME}_backup_${TIMESTAMP}"

echo "Creating backup directory: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Copy all project files
echo "📁 Backing up project files..."
cp deploy-enhanced-mcp-cloudshell.sh "$BACKUP_DIR/"
cp mcp_client.py "$BACKUP_DIR/"
cp test_mcp.py "$BACKUP_DIR/"
cp test_tr_urls.py "$BACKUP_DIR/"
cp PROJECT_SUMMARY.md "$BACKUP_DIR/"
cp PHASE2_PLAN.md "$BACKUP_DIR/"

# Create project metadata
cat > "$BACKUP_DIR/PROJECT_METADATA.json" << EOF
{
  "project_name": "$PROJECT_NAME",
  "backup_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "phase": "Phase 1 - Complete",
  "version": "1.0.0",
  "lambda_function": "a208194-it-helpdesk-enhanced-mcp-server",
  "aws_account": "818565325759",
  "region": "us-east-1",
  "target_id": "GCRBAIY1SP",
  "gateway": "a208194-askjulius-agentcore-gateway-mcp-iam",
  "status": "Deployed and Functional",
  "next_phase": "AgentCore MCP Target + Bedrock Knowledge Base"
}
EOF

# Create quick reference
cat > "$BACKUP_DIR/QUICK_REFERENCE.md" << EOF
# Quick Reference - Enhanced IT Helpdesk MCP Server

## 🚀 Quick Start
\`\`\`bash
# Test the server
python mcp_client.py --interactive

# Direct Lambda test
aws lambda invoke --function-name a208194-it-helpdesk-enhanced-mcp-server --payload '{"method": "tools/list", "params": {}}' response.json
\`\`\`

## 📋 Key Information
- **Function:** a208194-it-helpdesk-enhanced-mcp-server
- **Account:** 818565325759
- **Region:** us-east-1
- **Target:** GCRBAIY1SP

## 🔧 Available Tools
1. enhanced_search_it_support - AI-powered IT support
2. reset_password - Password reset help
3. check_m_account - M account assistance
4. cloud_tool_access - Cloud access help
5. aws_access - AWS account procedures
6. vpn_troubleshooting - VPN issues
7. email_troubleshooting - Email problems
8. software_installation - Software help

## ✅ Status: Ready for Phase 2
EOF

# Create compressed archive
echo "🗜️ Creating compressed archive..."
tar -czf "${BACKUP_DIR}.tar.gz" "$BACKUP_DIR"

echo "✅ Backup complete!"
echo "📦 Archive: ${BACKUP_DIR}.tar.gz"
echo "📁 Directory: $BACKUP_DIR"
echo ""
echo "🎉 Phase 1 Complete - Enhanced IT Helpdesk MCP Server"
echo "🚀 Ready for Phase 2: AgentCore MCP Target + Bedrock Knowledge Base"
echo ""
echo "Next steps:"
echo "1. Focus on recreating MCP setup using specific MCP target in AgentCore gateway"
echo "2. Create Bedrock knowledge base to integrate with Enhanced IT Helpdesk MCP Server"