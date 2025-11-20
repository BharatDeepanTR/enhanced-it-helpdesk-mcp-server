#!/usr/bin/env python3
"""
Agent Core Runtime Diagnostic Script
=====================================

Diagnoses issues with Agent Core Runtime:
Runtime ID: a208194_chatops_route_dns_lookup-Zg3E6G5ZDV

This script focuses on Agent Core Runtime specific issues, not regular Lambda functions.
"""

import boto3
import json
import logging
import time
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional

class AgentCoreRuntimeDiagnostic:
    """Diagnostic tool for Agent Core Runtime issues"""
    
    def __init__(self):
        """Initialize the diagnostic tool"""
        self.region = 'us-east-1'
        self.runtime_id = 'a208194_chatops_route_dns_lookup-Zg3E6G5ZDV'
        self.agent_name = 'a208194_chatops_route_dns_lookup'
        self.setup_logging()
        
        self.logger.info(f"🔍 Agent Core Runtime Diagnostic initialized")
        self.logger.info(f"🎯 Runtime ID: {self.runtime_id}")

    def setup_logging(self):
        """Configure logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger('AgentCoreRuntimeDiagnostic')

    def check_agent_core_runtime_logs(self) -> Dict[str, Any]:
        """Check Agent Core Runtime specific logs"""
        self.logger.info("📋 Checking Agent Core Runtime logs...")
        
        try:
            # The specific log group for Agent Core Runtime
            log_group = f'/aws/vendedlogs/bedrock-agentcore/runtime/APPLICATION_LOGS/{self.runtime_id}'
            
            cloudwatch = boto3.client('logs', region_name=self.region)
            
            print("\n" + "="*80)
            print("📋 AGENT CORE RUNTIME LOGS ANALYSIS")
            print("="*80)
            print(f"📁 Log Group: {log_group}")
            
            # Check if log group exists
            try:
                response = cloudwatch.describe_log_groups(
                    logGroupNamePrefix=log_group
                )
                
                if not response.get('logGroups'):
                    print("❌ Log group not found")
                    return {'status': 'no_logs', 'issue': 'Log group not found'}
                
                print("✅ Log group found")
                
                # Get recent log streams
                streams_response = cloudwatch.describe_log_streams(
                    logGroupName=log_group,
                    orderBy='LastEventTime',
                    descending=True,
                    limit=5
                )
                
                log_streams = streams_response.get('logStreams', [])
                print(f"📊 Found {len(log_streams)} log streams")
                
                if not log_streams:
                    print("⚠️ No log streams found - runtime may not be starting")
                    return {'status': 'no_streams', 'issue': 'No log streams'}
                
                # Get recent logs
                recent_logs = []
                for stream in log_streams[:2]:  # Check last 2 streams
                    stream_name = stream['logStreamName']
                    print(f"\n📄 Stream: {stream_name}")
                    print(f"   Last Event: {datetime.fromtimestamp(stream.get('lastEventTime', 0)/1000)}")
                    
                    # Get log events
                    try:
                        events_response = cloudwatch.get_log_events(
                            logGroupName=log_group,
                            logStreamName=stream_name,
                            startTime=int((datetime.now() - timedelta(hours=1)).timestamp() * 1000),
                            limit=50
                        )
                        
                        events = events_response.get('events', [])
                        print(f"   📝 Events: {len(events)}")
                        
                        for event in events[-10:]:  # Last 10 events
                            timestamp = datetime.fromtimestamp(event['timestamp']/1000)
                            message = event['message'].strip()
                            print(f"   {timestamp}: {message}")
                            recent_logs.append({
                                'timestamp': timestamp,
                                'message': message
                            })
                    
                    except Exception as e:
                        print(f"   ⚠️ Could not read stream: {str(e)}")
                
                return {
                    'status': 'success',
                    'log_streams': len(log_streams),
                    'recent_logs': recent_logs
                }
                
            except Exception as e:
                print(f"❌ Error accessing log group: {str(e)}")
                return {'status': 'error', 'error': str(e)}
                
        except Exception as e:
            self.logger.error(f"❌ Log analysis failed: {str(e)}")
            return {'status': 'error', 'error': str(e)}

    def check_ecr_container_status(self) -> Dict[str, Any]:
        """Check ECR container image status"""
        self.logger.info("🐳 Checking ECR container status...")
        
        try:
            ecr = boto3.client('ecr', region_name=self.region)
            
            print("\n" + "="*80)
            print("🐳 ECR CONTAINER STATUS")
            print("="*80)
            
            # Known repository from earlier analysis
            repository_name = 'dns-lookup-service'
            print(f"📦 Repository: {repository_name}")
            
            try:
                # Check repository exists
                repo_response = ecr.describe_repositories(
                    repositoryNames=[repository_name]
                )
                
                repository = repo_response['repositories'][0]
                print(f"✅ Repository found")
                print(f"   URI: {repository['repositoryUri']}")
                print(f"   Created: {repository['createdAt']}")
                
                # Check images
                images_response = ecr.list_images(
                    repositoryName=repository_name,
                    maxResults=10
                )
                
                images = images_response.get('imageIds', [])
                print(f"🖼️ Images: {len(images)} found")
                
                if images:
                    print("✅ Container images available")
                    return {'status': 'success', 'images': len(images)}
                else:
                    print("❌ No container images found")
                    return {'status': 'no_images', 'issue': 'No container images'}
                
            except ecr.exceptions.RepositoryNotFoundException:
                print(f"❌ Repository '{repository_name}' not found")
                return {'status': 'no_repository', 'issue': 'Repository not found'}
                
        except Exception as e:
            self.logger.error(f"❌ ECR check failed: {str(e)}")
            return {'status': 'error', 'error': str(e)}

    def test_agent_core_runtime_directly(self) -> Dict[str, Any]:
        """Test Agent Core Runtime directly"""
        self.logger.info("🧪 Testing Agent Core Runtime directly...")
        
        try:
            bedrock_runtime = boto3.client('bedrock-agent-runtime', region_name=self.region)
            
            print("\n" + "="*80)
            print("🧪 DIRECT RUNTIME TESTING")
            print("="*80)
            
            # Try to find the correct agent ID (short format)
            bedrock_agent = boto3.client('bedrock-agent', region_name=self.region)
            
            try:
                agents_response = bedrock_agent.list_agents(maxResults=50)
                agents = agents_response.get('agentSummaries', [])
                
                dns_agent_id = None
                for agent in agents:
                    if 'dns' in agent.get('agentName', '').lower() or 'chatops' in agent.get('agentName', '').lower():
                        agent_id = agent.get('agentId')
                        if len(agent_id) <= 10 and agent_id.isalnum():
                            dns_agent_id = agent_id
                            print(f"🎯 Found DNS Agent ID: {agent_id}")
                            break
                
                if dns_agent_id:
                    # Test with different aliases
                    test_aliases = ['TSTALIASID', 'DRAFT', 'PROD']
                    
                    for alias in test_aliases:
                        try:
                            print(f"\n🧪 Testing with alias: {alias}")
                            
                            response = bedrock_runtime.invoke_agent(
                                agentId=dns_agent_id,
                                agentAliasId=alias,
                                sessionId=f"diagnostic-{datetime.now().strftime('%Y%m%d%H%M%S')}",
                                inputText="test connection"
                            )
                            
                            print(f"✅ Success with alias: {alias}")
                            return {'status': 'success', 'working_alias': alias}
                            
                        except Exception as e:
                            error_msg = str(e)
                            if "ValidationException" in error_msg:
                                print(f"❌ Validation error: {error_msg}")
                            elif "ResourceNotFoundException" in error_msg:
                                print(f"❌ Resource not found: {alias}")
                            else:
                                print(f"❌ Error with {alias}: {error_msg}")
                else:
                    print("❌ No valid DNS agent ID found")
                    return {'status': 'no_agent', 'issue': 'No valid agent ID found'}
                    
            except Exception as e:
                print(f"❌ Agent discovery failed: {str(e)}")
                return {'status': 'error', 'error': str(e)}
                
        except Exception as e:
            self.logger.error(f"❌ Direct testing failed: {str(e)}")
            return {'status': 'error', 'error': str(e)}

    def diagnose_runtime_startup_failure(self) -> Dict[str, Any]:
        """Diagnose why runtime startup is failing"""
        self.logger.info("🔍 Diagnosing runtime startup failure...")
        
        print("\n" + "="*80)
        print("🔍 RUNTIME STARTUP FAILURE ANALYSIS")
        print("="*80)
        
        common_issues = [
            {
                'issue': 'Container Image Not Found',
                'description': 'ECR container image is missing or corrupted',
                'solution': 'Check ECR repository and rebuild container if needed'
            },
            {
                'issue': 'IAM Permission Issues',
                'description': 'Runtime lacks permissions to execute',
                'solution': 'Check IAM role permissions for Agent Core Runtime'
            },
            {
                'issue': 'Container Startup Failure',
                'description': 'Container fails to start due to code errors',
                'solution': 'Check application logs for startup errors'
            },
            {
                'issue': 'Resource Allocation',
                'description': 'Insufficient memory or CPU allocated',
                'solution': 'Check runtime resource configuration'
            },
            {
                'issue': 'Environment Variables',
                'description': 'Missing required environment variables',
                'solution': 'Verify all required environment variables are set'
            }
        ]
        
        print("🔧 COMMON RUNTIME STARTUP ISSUES:")
        for i, issue in enumerate(common_issues, 1):
            print(f"\n{i}. {issue['issue']}")
            print(f"   📝 {issue['description']}")
            print(f"   🔧 {issue['solution']}")
        
        return {'status': 'analysis_complete', 'issues': common_issues}

    def generate_fix_recommendations(self) -> None:
        """Generate specific fix recommendations"""
        
        print("\n" + "="*80)
        print("🔧 AGENT CORE RUNTIME FIX RECOMMENDATIONS")
        print("="*80)
        
        recommendations = [
            {
                'priority': 'HIGH',
                'action': 'Check Container Image',
                'details': [
                    'Verify ECR repository dns-lookup-service exists',
                    'Ensure container image is properly built',
                    'Check image compatibility with Agent Core Runtime'
                ]
            },
            {
                'priority': 'HIGH', 
                'action': 'Review Runtime Configuration',
                'details': [
                    'Check Agent Core Runtime settings in console',
                    'Verify resource allocation (memory, CPU)',
                    'Ensure runtime is in READY state'
                ]
            },
            {
                'priority': 'MEDIUM',
                'action': 'Compare with Working Agent',
                'details': [
                    'Copy configuration from working account agent',
                    'Match IAM role and permissions',
                    'Verify environment variables'
                ]
            },
            {
                'priority': 'MEDIUM',
                'action': 'Check Application Code',
                'details': [
                    'Verify main entry point exists',
                    'Check for syntax or import errors',
                    'Ensure all dependencies are included'
                ]
            }
        ]
        
        for rec in recommendations:
            print(f"\n🎯 {rec['priority']} PRIORITY: {rec['action']}")
            for detail in rec['details']:
                print(f"   • {detail}")
        
        print(f"\n💡 NEXT STEPS:")
        print(f"1. Start with HIGH priority items")
        print(f"2. Test after each fix")
        print(f"3. Check logs after each change")
        print(f"4. Compare with working account agent configuration")

    def run_comprehensive_diagnostic(self):
        """Run complete diagnostic analysis"""
        
        print("\n🔍 AGENT CORE RUNTIME COMPREHENSIVE DIAGNOSTIC")
        print("="*70)
        print(f"🕒 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🎯 Runtime ID: {self.runtime_id}")
        print(f"🤖 Agent Name: {self.agent_name}")
        print("="*70)
        
        # 1. Check logs
        log_results = self.check_agent_core_runtime_logs()
        
        # 2. Check ECR container
        ecr_results = self.check_ecr_container_status()
        
        # 3. Test runtime directly
        runtime_results = self.test_agent_core_runtime_directly()
        
        # 4. Analyze startup failure
        startup_results = self.diagnose_runtime_startup_failure()
        
        # 5. Generate recommendations
        self.generate_fix_recommendations()
        
        print("\n" + "="*80)
        print("📊 DIAGNOSTIC SUMMARY")
        print("="*80)
        print(f"📋 Log Analysis: {log_results.get('status', 'unknown')}")
        print(f"🐳 ECR Container: {ecr_results.get('status', 'unknown')}")
        print(f"🧪 Runtime Test: {runtime_results.get('status', 'unknown')}")
        print(f"🔍 Startup Analysis: {startup_results.get('status', 'unknown')}")
        
        if any(result.get('status') == 'success' for result in [log_results, ecr_results, runtime_results]):
            print("\n✅ Some components are working - focus on failing areas")
        else:
            print("\n❌ Multiple issues detected - systematic fix needed")

def main():
    """Main execution function"""
    try:
        diagnostic = AgentCoreRuntimeDiagnostic()
        diagnostic.run_comprehensive_diagnostic()
        
    except KeyboardInterrupt:
        print("\n🛑 Diagnostic interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")
        logging.error(f"Unexpected error in main: {str(e)}")

if __name__ == "__main__":
    main()