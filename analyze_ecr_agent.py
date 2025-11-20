#!/usr/bin/env python3
"""
ECR Agent Source Code Analysis Tool
===================================

Tool to examine the DNS lookup agent source code in ECR repository
to understand its functionality, tools, and expected prompt format.

This will help us understand:
1. What DNS functions the agent provides
2. Expected input format and prompt structure
3. Available tools and their parameters
4. How to properly test the agent via runtime
"""

import boto3
import json
import base64
import tarfile
import tempfile
import os
from pathlib import Path
import logging
from datetime import datetime

class ECRAgentAnalyzer:
    """ECR Agent Source Code Analyzer"""
    
    def __init__(self):
        """Initialize the ECR analyzer"""
        self.region = 'us-east-1'
        self.account_id = '818565325759'
        self.repository_name = 'dns-lookup-service'
        self.agent_runtime_id = 'a208194_chatops_route_dns_lookup-Zg3E6G5ZDV'
        
        self.setup_logging()
        self._init_aws_clients()
        
        self.logger.info("🔍 ECR Agent Analyzer initialized")
        self.logger.info(f"📦 Repository: {self.repository_name}")
        self.logger.info(f"🤖 Agent Runtime ID: {self.agent_runtime_id}")

    def setup_logging(self):
        """Configure logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger('ECRAnalyzer')

    def _init_aws_clients(self):
        """Initialize AWS clients"""
        try:
            self.ecr = boto3.client('ecr', region_name=self.region)
            
            # Verify authentication
            sts = boto3.client('sts', region_name=self.region)
            identity = sts.get_caller_identity()
            
            self.logger.info("✅ AWS clients initialized successfully")
            self.logger.info(f"🔐 Account: {identity.get('Account')}")
            
        except Exception as e:
            self.logger.error(f"❌ AWS initialization failed: {str(e)}")
            raise

    def get_ecr_auth_token(self):
        """Get ECR authorization token"""
        try:
            response = self.ecr.get_authorization_token()
            token_data = response['authorizationData'][0]
            token = token_data['authorizationToken']
            
            # Decode the token (it's base64 encoded username:password)
            decoded_token = base64.b64decode(token).decode('utf-8')
            username, password = decoded_token.split(':', 1)
            
            return {
                'username': username,
                'password': password,
                'endpoint': token_data['proxyEndpoint']
            }
            
        except Exception as e:
            self.logger.error(f"❌ Failed to get ECR auth token: {str(e)}")
            return None

    def list_repository_images(self):
        """List all images in the DNS lookup service repository"""
        try:
            self.logger.info("📋 Listing repository images...")
            
            response = self.ecr.describe_images(
                repositoryName=self.repository_name,
                maxResults=50
            )
            
            images = response.get('imageDetails', [])
            
            self.logger.info(f"🎯 Found {len(images)} images in repository")
            
            return images
            
        except Exception as e:
            self.logger.error(f"❌ Failed to list repository images: {str(e)}")
            return []

    def get_repository_info(self):
        """Get repository information"""
        try:
            self.logger.info("📋 Getting repository information...")
            
            response = self.ecr.describe_repositories(
                repositoryNames=[self.repository_name]
            )
            
            repo_info = response.get('repositories', [])
            if repo_info:
                repo = repo_info[0]
                
                print("\n" + "="*70)
                print("📦 ECR REPOSITORY INFORMATION")
                print("="*70)
                print(f"📛 Repository Name: {repo.get('repositoryName')}")
                print(f"🆔 Repository URI: {repo.get('repositoryUri')}")
                print(f"📅 Created: {repo.get('createdAt')}")
                print(f"🔄 Image Count: {repo.get('imageScanningConfiguration', {}).get('scanOnPush', 'N/A')}")
                print("="*70)
                
                return repo
            
        except Exception as e:
            self.logger.error(f"❌ Failed to get repository info: {str(e)}")
            return None

    def analyze_image_manifest(self, image_digest):
        """Analyze image manifest to understand the agent structure"""
        try:
            self.logger.info(f"🔍 Analyzing image manifest: {image_digest[:12]}...")
            
            # Get image manifest
            response = self.ecr.get_download_url_for_layer(
                repositoryName=self.repository_name,
                layerDigest=image_digest
            )
            
            # For security and complexity reasons, we'll focus on metadata analysis
            self.logger.info("ℹ️ Image manifest analysis would require Docker layer extraction")
            self.logger.info("ℹ️ Alternative: Check agent configuration files or documentation")
            
        except Exception as e:
            self.logger.error(f"❌ Failed to analyze image manifest: {str(e)}")

    def search_for_agent_config_files(self):
        """Search for agent configuration files or documentation"""
        
        # Look for common agent configuration patterns
        config_patterns = [
            'agent.json', 'config.json', 'manifest.json',
            'README.md', 'AGENT.md', 'docs/',
            'prompt.txt', 'instructions.txt',
            'tools.json', 'functions.json'
        ]
        
        print("\n" + "="*70)
        print("🔍 AGENT CONFIGURATION ANALYSIS")
        print("="*70)
        print("📝 Expected agent configuration files to look for:")
        for pattern in config_patterns:
            print(f"   • {pattern}")
        
        print(f"\n💡 Agent Analysis Recommendations:")
        print(f"1. Check ECR repository for these common files")
        print(f"2. Look for agent documentation or README")
        print(f"3. Check for tool/function definitions")
        print(f"4. Look for prompt templates or instructions")
        print("="*70)

    def generate_test_prompts_based_on_name(self):
        """Generate test prompts based on agent name analysis"""
        
        print("\n" + "="*70)
        print("🧪 SUGGESTED TEST PROMPTS")
        print("="*70)
        print("Based on agent name 'chatops_route_dns_lookup', here are suggested prompts:")
        print()
        
        test_prompts = [
            {
                'category': 'Basic DNS Lookup',
                'prompts': [
                    'dns lookup google.com',
                    'What is the IP address of amazon.com?',
                    'Resolve DNS for microsoft.com',
                    'lookup google.com'
                ]
            },
            {
                'category': 'Route Information', 
                'prompts': [
                    'route to 8.8.8.8',
                    'Show route information for google.com',
                    'trace route to amazon.com',
                    'routing info for cloudflare.com'
                ]
            },
            {
                'category': 'ChatOps Commands',
                'prompts': [
                    'dns google.com',
                    'route 8.8.8.8',
                    'lookup amazon.com',
                    'trace cloudflare.com'
                ]
            },
            {
                'category': 'Natural Language',
                'prompts': [
                    'Can you help me find the IP address of github.com?',
                    'I need to check the DNS records for my domain',
                    'Show me network routing to this server',
                    'What are the name servers for example.com?'
                ]
            }
        ]
        
        for category_info in test_prompts:
            print(f"📋 {category_info['category']}:")
            for prompt in category_info['prompts']:
                print(f"   • \"{prompt}\"")
            print()
        
        print("="*70)

    def create_runtime_test_template(self):
        """Create a template for testing the agent via runtime"""
        
        template = f"""#!/usr/bin/env python3
# DNS Agent Runtime Test Template
# Generated: {datetime.now().isoformat()}

import boto3

def test_dns_agent():
    # Agent Configuration
    agent_id = '{self.agent_runtime_id}'
    agent_alias_id = 'TSTALIASID'  # or 'DRAFT'
    
    # Initialize client
    bedrock_agent_runtime = boto3.client('bedrock-agent-runtime', region_name='{self.region}')
    
    # Test prompts (customize based on agent capabilities)
    test_prompts = [
        "dns lookup google.com",
        "What is the IP address of amazon.com?", 
        "route to 8.8.8.8",
        "Show me DNS records for github.com"
    ]
    
    for prompt in test_prompts:
        try:
            print(f"\\n🧪 Testing: {{prompt}}")
            
            response = bedrock_agent_runtime.invoke_agent(
                agentId=agent_id,
                agentAliasId=agent_alias_id,
                sessionId=f"test-session-{{int(time.time())}}",
                inputText=prompt
            )
            
            print(f"✅ Response received")
            # Process response as needed
            
        except Exception as e:
            print(f"❌ Error: {{str(e)}}")

if __name__ == "__main__":
    test_dns_agent()
"""
        
        template_filename = 'dns_agent_runtime_test_template.py'
        with open(template_filename, 'w') as f:
            f.write(template)
        
        print(f"\n📄 Runtime test template saved to: {template_filename}")
        self.logger.info(f"📄 Template created: {template_filename}")

    def run_analysis(self):
        """Run complete ECR agent analysis"""
        
        print("\n🔍 ECR AGENT SOURCE ANALYSIS")
        print("="*50)
        
        # Get repository information
        repo_info = self.get_repository_info()
        
        # List images
        images = self.list_repository_images()
        
        if images:
            print(f"\n📋 REPOSITORY IMAGES ({len(images)}):")
            print("-" * 40)
            for i, image in enumerate(images[:5], 1):  # Show first 5
                tags = image.get('imageTags', ['<no-tag>'])
                pushed = image.get('imagePushedAt', 'Unknown')
                size_mb = image.get('imageSizeInBytes', 0) / (1024 * 1024)
                
                print(f"{i}. Tags: {', '.join(tags)}")
                print(f"   Size: {size_mb:.1f} MB")
                print(f"   Pushed: {pushed}")
                print()
        
        # Show configuration analysis
        self.search_for_agent_config_files()
        
        # Generate test prompts
        self.generate_test_prompts_based_on_name()
        
        # Create runtime test template
        self.create_runtime_test_template()
        
        print(f"\n💡 NEXT STEPS:")
        print(f"1. Examine ECR repository manually for agent source code")
        print(f"2. Look for agent configuration files or documentation")
        print(f"3. Use generated test prompts to validate agent functionality")
        print(f"4. Customize the runtime test template based on findings")

def main():
    """Main execution function"""
    try:
        analyzer = ECRAgentAnalyzer()
        analyzer.run_analysis()
        
    except KeyboardInterrupt:
        print("\n🛑 Analysis interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")

if __name__ == "__main__":
    main()