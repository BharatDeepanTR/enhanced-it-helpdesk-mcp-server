# Quick Lambda Testing Commands - Enhanced IT Helpdesk MCP Server

## ✅ Working Commands (Tested and Verified)

### **1. List All Available Tools:**
```bash
echo '{"jsonrpc": "2.0", "method": "tools/list", "params": {}, "id": "test-1"}' > payload.json

aws lambda invoke \
  --function-name a208194-it-helpdesk-enhanced-mcp-server \
  --cli-binary-format raw-in-base64-out \
  --payload file://payload.json \
  response.json && cat response.json
```

### **2. Test Enhanced IT Search:**
```bash
echo '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "enhanced_search_it_support", "arguments": {"question": "How do I reset my password?", "session_id": "test-session-001"}}, "id": "test-2"}' > search_payload.json

aws lambda invoke \
  --function-name a208194-it-helpdesk-enhanced-mcp-server \
  --cli-binary-format raw-in-base64-out \
  --payload file://search_payload.json \
  response.json && cat response.json
```

### **3. Test Password Reset Tool:**
```bash
echo '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "reset_password", "arguments": {"query": "I forgot my TEN domain password", "session_id": "test-session-002"}}, "id": "test-3"}' > password_payload.json

aws lambda invoke \
  --function-name a208194-it-helpdesk-enhanced-mcp-server \
  --cli-binary-format raw-in-base64-out \
  --payload file://password_payload.json \
  response.json && cat response.json
```

### **4. Test VPN Troubleshooting:**
```bash
echo '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "vpn_troubleshooting", "arguments": {"query": "VPN connection keeps dropping", "session_id": "test-session-003"}}, "id": "test-4"}' > vpn_payload.json

aws lambda invoke \
  --function-name a208194-it-helpdesk-enhanced-mcp-server \
  --cli-binary-format raw-in-base64-out \
  --payload file://vpn_payload.json \
  response.json && cat response.json
```

### **5. Test Cloud Access Help:**
```bash
echo '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "cloud_tool_access", "arguments": {"query": "How do I get access to AWS cloud tools?", "session_id": "test-session-004"}}, "id": "test-5"}' > cloud_payload.json

aws lambda invoke \
  --function-name a208194-it-helpdesk-enhanced-mcp-server \
  --cli-binary-format raw-in-base64-out \
  --payload file://cloud_payload.json \
  response.json && cat response.json
```

## 📋 Available MCP Tools (Verified Working):

1. **enhanced_search_it_support** - AI-powered search with context memory
2. **reset_password** - Password reset guidance for TEN Domain
3. **check_m_account** - M account password assistance  
4. **cloud_tool_access** - Cloud tools and AWS access help
5. **aws_access** - AWS account access procedures
6. **vpn_troubleshooting** - VPN connectivity troubleshooting
7. **email_troubleshooting** - Email and Outlook issue resolution
8. **software_installation** - Software installation and licensing

## 🔑 Key Points:

- ✅ **Always use JSON-RPC 2.0 format** with `jsonrpc`, `method`, `params`, and `id` fields
- ✅ **Use `--cli-binary-format raw-in-base64-out`** for proper payload handling
- ✅ **Create payload files** instead of inline JSON to avoid encoding issues
- ✅ **Each tool requires different arguments** - check the schema in tools/list response
- ✅ **Session IDs** help maintain context across multiple calls

## ✅ Verified Response Format:

```json
{
  "StatusCode": 200,
  "ExecutedVersion": "$LATEST"
}
{
  "jsonrpc": "2.0",
  "result": {
    "content": [...],
    "session_info": {
      "session_id": "...",
      "enhanced_ai": true,
      "context_memory": true
    }
  },
  "id": "test-X"
}
```

---
**Status:** All commands tested and working ✅  
**Last Verified:** December 3, 2025