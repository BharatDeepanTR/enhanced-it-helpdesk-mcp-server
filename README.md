# Enhanced IT Helpdesk MCP Server

An AI-powered IT Helpdesk server implementing the Model Context Protocol (MCP) with AWS Lambda, featuring session memory, Thomson Reuters knowledge integration, and Claude Sonnet AI enhancement.

## 🚀 Overview

This project provides an intelligent IT support system that can:
- Answer IT support questions with AI enhancement
- Remember conversation context across sessions
- Provide Thomson Reuters-specific procedures and contacts
- Handle common IT issues (password reset, VPN, cloud access, etc.)
- Offer both interactive and programmatic access via MCP protocol

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   MCP Client    │───▶│  Bedrock         │───▶│  Lambda MCP     │
│   (Interactive) │    │  AgentCore       │    │  Server         │
└─────────────────┘    │  Gateway         │    └─────────────────┘
                       └──────────────────┘             │
                                                        ▼
                                               ┌─────────────────┐
                                               │  Claude Sonnet  │
                                               │  AI Enhancement │
                                               └─────────────────┘
```

## 📦 Deployment

### **AWS Lambda Function:**
- **Name:** `a208194-it-helpdesk-enhanced-mcp-server`
- **Runtime:** Python 3.14
- **Region:** us-east-1
- **Account:** 818565325759

### **Quick Deploy:**
```bash
./deploy-enhanced-mcp-cloudshell.sh
```

## 🛠️ Available MCP Tools

| Tool | Description | Category |
|------|-------------|----------|
| `enhanced_search_it_support` | AI-powered search with context memory | AI Enhancement |
| `reset_password` | Password reset guidance for TEN Domain | Authentication |
| `check_m_account` | M account password assistance | Account Management |
| `cloud_tool_access` | Cloud tools and AWS access help | Cloud Services |
| `aws_access` | AWS account access procedures | Cloud Services |
| `vpn_troubleshooting` | VPN connectivity troubleshooting | Network |
| `email_troubleshooting` | Email and Outlook issue resolution | Communication |
| `software_installation` | Software installation and licensing | Software |

## 🔧 Usage

### **Interactive Client:**
```bash
python mcp_client.py --interactive
```

### **Direct Lambda Testing:**
```bash
aws lambda invoke \
  --function-name a208194-it-helpdesk-enhanced-mcp-server \
  --payload '{"method": "tools/list", "params": {}}' \
  response.json
```

### **Ask a Question:**
```bash
python mcp_client.py --ask "How do I reset my password?"
```

## 📁 Project Files

- `deploy-enhanced-mcp-cloudshell.sh` - Main deployment script (1672 lines)
- `mcp_client.py` - Enhanced interactive Python client with menu system
- `test_mcp.py` - Basic connection test script
- `test_tr_urls.py` - URL validation test script
- `PROJECT_SUMMARY.md` - Complete project documentation
- `PHASE2_PLAN.md` - Future development roadmap
- `backup_project.sh` - Project backup utility

## ✅ Features

- ✅ **MCP Protocol Compliance** - Full JSON-RPC 2.0 support
- ✅ **AI Enhancement** - Claude Sonnet integration for intelligent responses
- ✅ **Session Memory** - Context retention across conversations
- ✅ **Interactive Menu** - User-friendly command interface
- ✅ **Thomson Reuters Integration** - TR-specific knowledge and procedures
- ✅ **Bedrock AgentCore** - Advanced memory management
- ✅ **Multi-Tool Support** - 8 specialized IT support tools

## 🔗 MCP Endpoint

### **Direct Lambda ARN:**
```
arn:aws:lambda:us-east-1:818565325759:function:a208194-it-helpdesk-enhanced-mcp-server
```

### **AgentCore Gateway:**
- **Gateway:** `a208194-askjulius-agentcore-gateway-mcp-iam`
- **Target:** `target-lambda-it-helpdesk-enhanced-mcp` (GCRBAIY1SP)

## 📊 Status

**Phase 1:** ✅ **COMPLETE** - Deployed and functional  
**Phase 2:** 🚧 **PLANNED** - AgentCore MCP Target + Bedrock Knowledge Base

## 🚀 Next Steps (Phase 2)

1. **AgentCore MCP Target Optimization**
   - Recreate MCP setup with specific MCP target configuration
   - Enhanced gateway performance and routing

2. **Bedrock Knowledge Base Integration**
   - Dynamic knowledge retrieval
   - SharePoint integration preparation
   - Scalable content management

## 📞 Support

For questions or issues:
- Check `PROJECT_SUMMARY.md` for detailed information
- Review `PHASE2_PLAN.md` for future development plans
- Test using the provided client tools

---

**Project Status:** Production Ready | **Last Updated:** December 3, 2025