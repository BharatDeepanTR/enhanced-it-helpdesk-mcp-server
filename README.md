# Enhanced Thomson Reuters IT Helpdesk MCP Server

AI-powered IT Helpdesk with **real Thomson Reuters Service Desk integration**, featuring authentic TR resources, source attribution, and Claude AI enhancement via Model Context Protocol (MCP).

## 🚀 Overview

This enhanced IT support system provides:
- **Real TR Service Desk URLs**: SharePoint, Teams chat, ServiceNow portal
- **Authentic TR Procedures**: Official password reset, VPN, AWS access guides  
- **Source Attribution**: Clear labeling of Internal TR vs AI-generated responses
- **Claude AI Enhancement**: Intelligent fallback for complex queries
- **Beautiful UI**: Professional Thomson Reuters-branded interface
- **Production Ready**: Deployed and tested with AgentCore Gateway integration

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

## 🏗️ Architecture

```
┌─────────────────────┐    ┌──────────────────────┐    ┌─────────────────────┐
│  TR Helpdesk UI     │───▶│  AgentCore Gateway   │───▶│  Enhanced Lambda    │
│  Client (Beautiful) │    │  MCP Protocol        │    │  MCP Server         │
│  tr_helpdesk_ui_    │    │  AWS IAM Auth        │    │  tr_it_helpdesk_    │
│  client.py          │    │                      │    │  lambda.py          │
└─────────────────────┘    └──────────────────────┘    └─────────────────────┘
                                                                  │
                                                                  ▼
                                               ┌─────────────────────────────────┐
                                               │  Real TR Resources + Claude AI  │
                                               │  • Service Desk SharePoint     │
                                               │  • Teams Live Chat Support     │
                                               │  • ServiceNow Portal          │
                                               │  • Official Password Reset    │
                                               └─────────────────────────────────┘
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

## 🛠️ Real Thomson Reuters IT Support Services

| Service | Description | Real TR Resources |
|---------|-------------|-------------------|
| **AI-Enhanced IT Support** | Claude AI assistance with TR context | Internal TR + AI-Generated responses |
| **DNS Troubleshooting** | Network connectivity and domain resolution | TR Network Operations Center |
| **Reset Password** | Windows, email, VPN password reset | https://pwreset.thomsonreuters.com |
| **AWS Cloud Access Request** | AWS console and service access | https://thomsonreuters.awsapps.com |
| **VPN Troubleshooting** | Remote access and connectivity issues | TR VPN Portal + NOC Support |
| **Email & Outlook Support** | Exchange, calendar, and email issues | TR Exchange Support Team |
| **SharePoint Resources** | Digital Accessibility and TR portals | https://trten.sharepoint.com |
| **List All Available Tools** | View all MCP tools and descriptions | Tool Discovery Interface |

## 🔧 Usage

### **Enhanced TR Helpdesk UI Client:**
```bash
python tr_helpdesk_ui_client.py
```

**Features:**
- 🎨 Beautiful Thomson Reuters-branded interface
- 🌐 8 IT support services with real TR resources
- 🔐 AWS IAM authentication via AgentCore Gateway
- 📱 Interactive menu with emojis and professional formatting
- ⚡ All 18 tools properly mapped and functional

### **Real Thomson Reuters Service Desk Resources:**

**🌐 Service Desk SharePoint:** https://trten.sharepoint.com/sites/TR_Service_Desk_Test
**💬 Teams Live Chat Support:** Direct URL to Service Desk Teams channel
**🎫 ServiceNow Portal:** https://thomsonreuters.service-now.com
**🔐 Password Reset Portal:** https://pwreset.thomsonreuters.com/r/passwordreset/flow-selection

### **Direct Lambda Testing:**
```bash
# Test the enhanced TR helpdesk (Gateway-compatible format)
aws lambda invoke \
  --function-name a208194-it-helpdesk-enhanced-mcp-server \
  --cli-binary-format raw-in-base64-out \
  --payload '{"query": "How do I reset my password?"}' \
  response.json && cat response.json
```

### **MCP Protocol Testing (JSON-RPC 2.0):**
```bash
# Create JSON-RPC 2.0 payload file
echo '{"jsonrpc": "2.0", "method": "tools/list", "params": {}, "id": "test-1"}' > payload.json

# Invoke Lambda function
aws lambda invoke \
  --function-name a208194-it-helpdesk-enhanced-mcp-server \
  --cli-binary-format raw-in-base64-out \
  --payload file://payload.json \
  response.json && cat response.json
```

### **Test Specific TR Service:**
```bash
# Test password reset service
echo '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "reset_password", "arguments": {"query": "I forgot my password", "session_id": "test-session"}}, "id": "test-2"}' > test_payload.json

aws lambda invoke \
  --function-name a208194-it-helpdesk-enhanced-mcp-server \
  --cli-binary-format raw-in-base64-out \
  --payload file://test_payload.json \
  response.json && cat response.json
```

## 📁 Core Files (Enhanced Version 2.0)

- **`tr_it_helpdesk_lambda.py`** - Production Lambda with real TR Service Desk URLs and source attribution
- **`tr_helpdesk_ui_client.py`** - Beautiful Thomson Reuters-branded MCP client interface  
- **`requirements.txt`** - Essential dependencies (boto3, requests)

## ✨ Key Features

- ✅ **Real TR Service Desk Integration** - Authentic SharePoint, Teams, ServiceNow URLs
- ✅ **Source Attribution** - Clear labeling of Internal TR vs AI-generated responses  
- ✅ **Production Ready** - Deployed and tested on AWS Lambda
- ✅ **Beautiful UI** - Professional TR-branded interface with enhanced user experience
- ✅ **AgentCore Gateway Compatible** - Full MCP protocol support with AWS IAM authentication
- ✅ **Claude AI Enhanced** - Intelligent fallback for complex IT queries
- ✅ **8 IT Support Services** - Comprehensive coverage of common TR IT issues

## 🔗 MCP Endpoint

### **Direct Lambda ARN:**
```
arn:aws:lambda:us-east-1:818565325759:function:a208194-it-helpdesk-enhanced-mcp-server
```

### **AgentCore Gateway (Production):**
- **Gateway ID:** `a208194-askjulius-agentcore-gateway-mcp-iam-fvro4phd59`
- **Status:** ✅ Active and operational
- **Authentication:** AWS IAM with proper trust policy
- **Protocol:** MCP-compatible JSON-RPC 2.0

## 📊 Status

**✅ Enhanced Version 2.0: PRODUCTION READY**
- ✅ Real Thomson Reuters Service Desk URLs integrated
- ✅ Source attribution implemented for transparency  
- ✅ Beautiful UI deployed and tested
- ✅ AgentCore Gateway routing functional
- ✅ Claude AI enhancement operational
- ✅ All 8 IT services and 18 tools working

## 🎯 What Makes This Special

**🔍 Source Transparency:**
Users always know if responses come from:
- **📋 Internal TR Resources** - Official procedures and links
- **🤖 AI-Generated Content** - Claude AI enhanced responses

**🌐 Real Service Desk Integration:**
- Official TR Service Desk SharePoint site
- Direct Teams chat support links  
- Authentic ServiceNow portal access
- Real password reset procedures

**🎨 Professional Experience:**
- Thomson Reuters branding and colors
- Intuitive menu system with emojis
- Error handling and user guidance
- Session management and tracking

## 📞 Thomson Reuters IT Support

**🌐 Global Service Desk:** +1-855-888-8899 (24/7)
**🎫 ServiceNow Portal:** https://thomsonreuters.service-now.com  
**📧 Email Support:** servicedesk@thomsonreuters.com

For technical questions about this MCP server:
- Check the deployed Lambda function: `a208194-it-helpdesk-enhanced-mcp-server`
- Test with the beautiful UI client: `tr_helpdesk_ui_client.py`
- Review real TR Service Desk resources integrated in the system

---

**🚀 Enhanced Thomson Reuters IT Helpdesk MCP Server v2.0**  
**Production Ready** | **Real Service Desk Integration** | **Source Attribution** | **Last Updated:** December 3, 2025