# Phase 2 Development Plan - Enhanced IT Helpdesk MCP Server

## 🎯 Phase 2 Objectives

### **1. MCP Target in AgentCore Gateway Setup**
Create a proper MCP target configuration in Bedrock AgentCore Gateway for optimized performance and integration.

### **2. Bedrock Knowledge Base Integration**
Develop and integrate a Bedrock Knowledge Base with the current Enhanced IT Helpdesk MCP Server for dynamic knowledge retrieval.

## 📋 Detailed Implementation Plan

### **Focus Area 1: AgentCore Gateway MCP Target**

#### **Current State:**
- Lambda function: `a208194-it-helpdesk-enhanced-mcp-server` 
- Target: `target-lambda-it-helpdesk-enhanced-mcp` (GCRBAIY1SP)
- Gateway: `a208194-askjulius-agentcore-gateway-mcp-iam`

#### **Objectives:**
- [ ] Recreate MCP setup with dedicated MCP target
- [ ] Optimize AgentCore gateway configuration
- [ ] Enhance target routing and performance
- [ ] Implement proper MCP protocol handling at gateway level

#### **Implementation Steps:**
1. **Analyze Current Target Configuration**
   - Review existing target settings
   - Identify optimization opportunities
   - Document current performance metrics

2. **Create New MCP-Specific Target**
   - Design dedicated MCP target architecture
   - Configure optimal routing rules
   - Implement enhanced error handling

3. **Test and Validate**
   - Performance testing
   - Load testing
   - MCP protocol compliance verification

#### **Expected Outcomes:**
- Better performance and reliability
- Enhanced MCP protocol support
- Improved error handling and monitoring

---

### **Focus Area 2: Bedrock Knowledge Base Integration**

#### **Current State:**
- Hardcoded knowledge base in Lambda function
- Thomson Reuters specific information embedded
- Limited to predefined Q&A pairs

#### **Objectives:**
- [ ] Create Bedrock Knowledge Base
- [ ] Integrate with SharePoint (future)
- [ ] Enable dynamic knowledge retrieval
- [ ] Maintain current MCP functionality

#### **Implementation Steps:**

1. **Create Bedrock Knowledge Base**
   ```bash
   # Step 1: Create Knowledge Base
   aws bedrock-agent create-knowledge-base \
     --name "tr-it-helpdesk-knowledge-base" \
     --description "Thomson Reuters IT Helpdesk Knowledge Base" \
     --role-arn "arn:aws:iam::818565325759:role/bedrock-kb-role"
   ```

2. **Prepare Knowledge Content**
   - Extract current knowledge from Lambda
   - Format for Bedrock KB ingestion
   - Add Thomson Reuters specific documentation

3. **Configure Data Source**
   - Set up S3 bucket for knowledge documents
   - Configure ingestion pipeline
   - Set up automatic synchronization

4. **Integrate with MCP Server**
   - Update Lambda function to query Bedrock KB
   - Implement fallback to local knowledge
   - Add caching for performance

5. **Test Integration**
   - Validate knowledge retrieval
   - Test MCP tool responses
   - Performance testing

#### **Architecture Overview:**
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   MCP Client    │───▶│  AgentCore       │───▶│  Lambda MCP     │
│                 │    │  Gateway         │    │  Server         │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                                                         ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   SharePoint    │───▶│  Bedrock         │◀───│  Enhanced       │
│   (Future)      │    │  Knowledge Base  │    │  Responses      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 🗓️ Timeline & Priorities

### **Week 1: Planning & Setup**
- [ ] Analyze current AgentCore target configuration
- [ ] Design new MCP target architecture
- [ ] Plan Bedrock Knowledge Base structure

### **Week 2: AgentCore MCP Target**
- [ ] Implement new MCP-specific target
- [ ] Configure gateway optimization
- [ ] Test and validate performance

### **Week 3: Bedrock Knowledge Base**
- [ ] Create Bedrock Knowledge Base
- [ ] Prepare and ingest knowledge content
- [ ] Configure data sources

### **Week 4: Integration & Testing**
- [ ] Integrate KB with Lambda function
- [ ] End-to-end testing
- [ ] Performance optimization
- [ ] Documentation and handover

## 📊 Success Criteria

### **AgentCore MCP Target:**
- [ ] Improved response time (< 2 seconds)
- [ ] Enhanced error handling
- [ ] Better monitoring and logging
- [ ] Seamless MCP protocol compliance

### **Bedrock Knowledge Base:**
- [ ] Dynamic knowledge retrieval working
- [ ] Maintains all current MCP tool functionality
- [ ] Scalable knowledge management
- [ ] Ready for SharePoint integration

## 🔧 Technical Prerequisites

### **Required AWS Services:**
- Bedrock Knowledge Base
- Bedrock Agent (existing)
- S3 for knowledge storage
- IAM roles and permissions

### **Required Permissions:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:*",
        "bedrock-agent:*",
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "*"
    }
  ]
}
```

## 📁 Project Files for Phase 2

### **Current Files to Preserve:**
- `deploy-enhanced-mcp-cloudshell.sh` - Current working deployment
- `mcp_client.py` - Interactive client
- `PROJECT_SUMMARY.md` - This documentation

### **New Files to Create:**
- `bedrock-kb-setup.sh` - Bedrock Knowledge Base creation
- `agentcore-mcp-target.sh` - New MCP target configuration
- `knowledge-content/` - Directory for KB content
- `phase2-deploy.sh` - Combined Phase 2 deployment

---

**Next Action:** Begin Phase 2 development focusing on AgentCore MCP Target optimization and Bedrock Knowledge Base creation.