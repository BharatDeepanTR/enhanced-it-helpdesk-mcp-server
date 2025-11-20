#!/usr/bin/env python3
"""
Comprehensive DNS Agent Logging and Debug Capture
=================================================

This script captures all available logs and debugging information for the 
DNS agent runtime failure, including:
- CloudWatch logs for Agent Core Runtime
- Lambda function logs
- Agent configuration details
- Runtime error traces
- Network and IAM diagnostics
"""

import boto3
import json
import time
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional

class DNSAgentDebugger:
    """Comprehensive DNS Agent debugging and log capture"""
    
    def __init__(self):
        """Initialize the debugger"""
        self.region = 'us-east-1'
        self.setup_logging()
        
        # Known agent information
        self.agent_runtime_id = 'a208194_chatops_route_dns_lookup-Zg3E6G5ZDV'
        self.agent_name = 'a208194_chatops_route_dns_lookup'
        self.endpoint_name = 'chatops_dns_endpoint'
        
        self.debug_session = f"debug-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
        
        self.logger.info("🔍 DNS Agent Debugger initialized")
        self.logger.info(f"📋 Debug Session: {self.debug_session}")

    def setup_logging(self):
        """Configure comprehensive logging"""
        # Create logger
        self.logger = logging.getLogger('DNSAgentDebugger')
        self.logger.setLevel(logging.DEBUG)
        
        # Clear any existing handlers
        self.logger.handlers.clear()
        
        # Console handler
        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.INFO)
        console_formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
        console_handler.setFormatter(console_formatter)
        self.logger.addHandler(console_handler)
        
        # File handler for detailed logs
        log_filename = f"dns_agent_debug_{self.debug_session}.log"
        file_handler = logging.FileHandler(log_filename)
        file_handler.setLevel(logging.DEBUG)
        file_formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        file_handler.setFormatter(file_formatter)
        self.logger.addHandler(file_handler)
        
        self.debug_log_file = log_filename
        self.logger.info(f"📄 Debug log file: {log_filename}")

    def _init_aws_clients(self):
        """Initialize AWS clients"""
        try:
            self.logs_client = boto3.client('logs', region_name=self.region)
            self.lambda_client = boto3.client('lambda', region_name=self.region)
            self.bedrock_agent = boto3.client('bedrock-agent', region_name=self.region)
            self.bedrock_runtime = boto3.client('bedrock-agent-runtime', region_name=self.region)
            self.iam_client = boto3.client('iam', region_name=self.region)
            
            self.logger.info("✅ AWS clients initialized")
            return True
        except Exception as e:
            self.logger.error(f"❌ Failed to initialize AWS clients: {str(e)}")
            return False

    def capture_agent_core_logs(self) -> List[Dict]:
        """Capture Agent Core Runtime CloudWatch logs"""
        self.logger.info("📋 Capturing Agent Core Runtime logs...")
        
        try:
            # Look for Agent Core log groups
            log_groups = []
            
            # Common Agent Core log group patterns
            patterns = [
                '/aws/bedrock/agentcore',
                '/aws/bedrock-agentcore',
                '/aws/lambda/bedrock-agentcore',
                f'/aws/bedrock/agentcore/{self.agent_runtime_id}',
                f'/aws/bedrock-agentcore/runtime/{self.agent_runtime_id}',
                '/aws/bedrock/agent-runtime'
            ]
            
            print("\n" + "="*80)
            print("📋 AGENT CORE CLOUDWATCH LOGS SEARCH")
            print("="*80)
            
            # Search for existing log groups
            response = self.logs_client.describe_log_groups()
            all_log_groups = [lg['logGroupName'] for lg in response.get('logGroups', [])]
            
            print(f"🔍 Found {len(all_log_groups)} total log groups")
            
            # Find Agent Core related log groups
            agent_log_groups = []
            keywords = ['bedrock', 'agent', 'agentcore', 'runtime', '208194']
            
            for log_group in all_log_groups:
                if any(keyword.lower() in log_group.lower() for keyword in keywords):
                    agent_log_groups.append(log_group)
                    print(f"   🎯 Found: {log_group}")
            
            if not agent_log_groups:
                print("❌ No Agent Core related log groups found")
                return []
            
            # Capture logs from the last 2 hours
            end_time = int(time.time() * 1000)
            start_time = end_time - (2 * 60 * 60 * 1000)  # 2 hours ago
            
            all_logs = []
            
            for log_group in agent_log_groups[:5]:  # Limit to first 5 to avoid rate limits
                try:
                    print(f"\n📖 Fetching logs from: {log_group}")
                    
                    # Get log streams
                    streams_response = self.logs_client.describe_log_streams(
                        logGroupName=log_group,
                        orderBy='LastEventTime',
                        descending=True,
                        limit=10
                    )
                    
                    log_streams = streams_response.get('logStreams', [])
                    print(f"   📊 Found {len(log_streams)} log streams")
                    
                    for stream in log_streams[:3]:  # Get latest 3 streams
                        stream_name = stream['logStreamName']
                        
                        try:
                            events_response = self.logs_client.get_log_events(
                                logGroupName=log_group,
                                logStreamName=stream_name,
                                startTime=start_time,
                                endTime=end_time,
                                limit=100
                            )
                            
                            events = events_response.get('events', [])
                            if events:
                                print(f"   📋 Stream {stream_name}: {len(events)} events")
                                
                                for event in events:
                                    log_entry = {
                                        'timestamp': event['timestamp'],
                                        'datetime': datetime.fromtimestamp(event['timestamp']/1000).isoformat(),
                                        'log_group': log_group,
                                        'log_stream': stream_name,
                                        'message': event['message']
                                    }
                                    all_logs.append(log_entry)
                                    
                                    # Print recent errors
                                    message = event['message'].lower()
                                    if any(keyword in message for keyword in ['error', 'exception', 'failed', 'timeout']):
                                        print(f"      🚨 ERROR: {event['message'][:200]}")
                                        
                        except Exception as e:
                            print(f"   ⚠️ Failed to fetch stream {stream_name}: {str(e)}")
                            
                except Exception as e:
                    print(f"❌ Failed to access log group {log_group}: {str(e)}")
            
            # Save all logs to file
            if all_logs:
                logs_filename = f"agent_core_logs_{self.debug_session}.json"
                with open(logs_filename, 'w') as f:
                    json.dump(all_logs, f, indent=2, default=str)
                
                print(f"\n💾 Saved {len(all_logs)} log entries to: {logs_filename}")
                
                # Analyze for specific errors
                self.analyze_log_patterns(all_logs)
            else:
                print("❌ No recent log entries found")
            
            return all_logs
            
        except Exception as e:
            self.logger.error(f"❌ Failed to capture Agent Core logs: {str(e)}")
            return []

    def analyze_log_patterns(self, logs: List[Dict]):
        """Analyze log patterns for common issues"""
        print(f"\n🔍 ANALYZING {len(logs)} LOG ENTRIES")
        print("-" * 50)
        
        error_patterns = {
            'runtime_startup': ['runtime startup', 'starting runtime', 'runtime initialization'],
            'lambda_errors': ['lambda error', 'function error', 'invocation failed'],
            'timeout_issues': ['timeout', 'timed out', 'deadline exceeded'],
            'permission_errors': ['access denied', 'unauthorized', 'permission'],
            'configuration_errors': ['configuration', 'config error', 'invalid config'],
            'network_issues': ['network', 'connection', 'dns resolution'],
            'resource_errors': ['resource not found', 'does not exist', 'not available']
        }
        
        pattern_counts = {pattern: 0 for pattern in error_patterns.keys()}
        recent_errors = []
        
        for log in logs:
            message = log['message'].lower()
            
            # Count patterns
            for pattern_name, keywords in error_patterns.items():
                if any(keyword in message for keyword in keywords):
                    pattern_counts[pattern_name] += 1
            
            # Collect recent errors
            if any(keyword in message for keyword in ['error', 'exception', 'failed']):
                recent_errors.append({
                    'timestamp': log['datetime'],
                    'source': log['log_group'],
                    'message': log['message'][:300]
                })
        
        # Report pattern analysis
        print("📊 ERROR PATTERN ANALYSIS:")
        for pattern, count in pattern_counts.items():
            if count > 0:
                print(f"   🚨 {pattern.replace('_', ' ').title()}: {count} occurrences")
        
        # Show recent errors
        if recent_errors:
            print(f"\n📋 RECENT ERRORS ({len(recent_errors)}):")
            for error in recent_errors[-5:]:  # Show last 5 errors
                print(f"   ⏰ {error['timestamp']}")
                print(f"   📍 {error['source']}")
                print(f"   💬 {error['message']}")
                print()

    def find_dns_lambda_functions(self) -> List[Dict]:
        """Find DNS-related Lambda functions"""
        self.logger.info("🔍 Searching for DNS Lambda functions...")
        
        try:
            print("\n" + "="*80)
            print("🔍 DNS LAMBDA FUNCTION SEARCH")
            print("="*80)
            
            # List all Lambda functions
            paginator = self.lambda_client.get_paginator('list_functions')
            dns_functions = []
            
            keywords = ['dns', 'lookup', 'route', 'chatops', '208194']
            
            for page in paginator.paginate():
                functions = page.get('Functions', [])
                
                for func in functions:
                    func_name = func['FunctionName'].lower()
                    description = func.get('Description', '').lower()
                    
                    if any(keyword in func_name or keyword in description for keyword in keywords):
                        dns_functions.append(func)
                        
                        print(f"\n🎯 FOUND DNS FUNCTION:")
                        print(f"   Name: {func['FunctionName']}")
                        print(f"   ARN: {func['FunctionArn']}")
                        print(f"   Runtime: {func['Runtime']}")
                        print(f"   State: {func['State']}")
                        print(f"   Last Modified: {func['LastModified']}")
                        
                        # Check function logs
                        self.capture_lambda_logs(func['FunctionName'])
            
            if not dns_functions:
                print("❌ No DNS-related Lambda functions found")
            
            return dns_functions
            
        except Exception as e:
            self.logger.error(f"❌ Failed to search Lambda functions: {str(e)}")
            return []

    def capture_lambda_logs(self, function_name: str):
        """Capture Lambda function CloudWatch logs"""
        try:
            log_group = f"/aws/lambda/{function_name}"
            
            print(f"   📋 Checking logs for: {log_group}")
            
            # Get recent log events
            end_time = int(time.time() * 1000)
            start_time = end_time - (60 * 60 * 1000)  # 1 hour ago
            
            try:
                # Get log streams
                streams_response = self.logs_client.describe_log_streams(
                    logGroupName=log_group,
                    orderBy='LastEventTime',
                    descending=True,
                    limit=3
                )
                
                streams = streams_response.get('logStreams', [])
                
                for stream in streams:
                    try:
                        events_response = self.logs_client.get_log_events(
                            logGroupName=log_group,
                            logStreamName=stream['logStreamName'],
                            startTime=start_time,
                            endTime=end_time,
                            limit=20
                        )
                        
                        events = events_response.get('events', [])
                        
                        if events:
                            print(f"   📊 Recent events: {len(events)}")
                            
                            # Show recent errors
                            for event in events:
                                message = event['message']
                                if any(keyword in message.lower() for keyword in ['error', 'exception', 'traceback']):
                                    timestamp = datetime.fromtimestamp(event['timestamp']/1000)
                                    print(f"   🚨 {timestamp}: {message[:200]}")
                        
                    except Exception as e:
                        print(f"   ⚠️ Cannot read stream: {str(e)}")
                        
            except Exception as e:
                print(f"   ❌ Cannot access logs: {str(e)}")
                
        except Exception as e:
            self.logger.error(f"❌ Failed to capture Lambda logs for {function_name}: {str(e)}")

    def test_agent_endpoint(self) -> Dict[str, Any]:
        """Test the agent endpoint with detailed error capture"""
        self.logger.info("🧪 Testing agent endpoint with error capture...")
        
        print("\n" + "="*80)
        print("🧪 AGENT ENDPOINT TESTING")
        print("="*80)
        
        test_results = {}
        
        try:
            # Test payload
            test_payload = {
                "inputText": "What is the IP address of google.com?",
                "sessionId": f"debug-test-{int(time.time())}",
                "sessionAttributes": {},
                "promptSessionAttributes": {}
            }
            
            print(f"📤 Test Payload:")
            print(json.dumps(test_payload, indent=2))
            
            # Attempt to invoke (this will likely fail, but we'll capture the error)
            start_time = time.time()
            
            try:
                # Try different approaches to invoke the agent
                
                # Approach 1: Direct runtime invocation (won't work due to long ID)
                print(f"\n🔄 Attempting direct runtime invocation...")
                try:
                    response = self.bedrock_runtime.invoke_agent(
                        agentId=self.agent_runtime_id,
                        agentAliasId='TSTALIASID',
                        sessionId=test_payload['sessionId'],
                        inputText=test_payload['inputText']
                    )
                    test_results['direct_invoke'] = 'success'
                    print("✅ Direct invocation successful")
                    
                except Exception as e:
                    test_results['direct_invoke'] = str(e)
                    print(f"❌ Direct invocation failed: {str(e)}")
                
                execution_time = time.time() - start_time
                test_results['execution_time'] = execution_time
                
            except Exception as e:
                test_results['general_error'] = str(e)
                print(f"❌ General test failed: {str(e)}")
            
            # Save detailed test results
            test_filename = f"agent_test_results_{self.debug_session}.json"
            with open(test_filename, 'w') as f:
                json.dump(test_results, f, indent=2, default=str)
            
            print(f"\n💾 Test results saved to: {test_filename}")
            
            return test_results
            
        except Exception as e:
            self.logger.error(f"❌ Agent endpoint test failed: {str(e)}")
            return {'error': str(e)}

    def generate_debug_report(self):
        """Generate comprehensive debug report"""
        print("\n" + "="*80)
        print("📋 COMPREHENSIVE DEBUG REPORT")
        print("="*80)
        print(f"🕒 Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🏷️ Debug Session: {self.debug_session}")
        
        # Summary of findings
        report = {
            'session': self.debug_session,
            'timestamp': datetime.now().isoformat(),
            'agent_info': {
                'runtime_id': self.agent_runtime_id,
                'agent_name': self.agent_name,
                'endpoint_name': self.endpoint_name
            },
            'debug_files': [
                self.debug_log_file,
                f"agent_core_logs_{self.debug_session}.json",
                f"agent_test_results_{self.debug_session}.json"
            ]
        }
        
        # Save main report
        report_filename = f"dns_agent_debug_report_{self.debug_session}.json"
        with open(report_filename, 'w') as f:
            json.dump(report, f, indent=2, default=str)
        
        print(f"\n📄 Main debug report: {report_filename}")
        print(f"📄 Detailed logs: {self.debug_log_file}")
        
        print(f"\n💡 NEXT STEPS:")
        print(f"   1. Review the captured CloudWatch logs for runtime startup errors")
        print(f"   2. Check Lambda function logs for underlying function issues")
        print(f"   3. Verify Agent Core Runtime configuration in the console")
        print(f"   4. Ensure the underlying Lambda function is working independently")
        print(f"   5. Check IAM permissions for Agent Core Runtime execution role")
        
        print("="*80)

    def run_comprehensive_debug(self):
        """Run complete debugging process"""
        print("\n🔍 DNS AGENT COMPREHENSIVE DEBUG SESSION")
        print("="*60)
        print(f"🕒 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🏷️ Session ID: {self.debug_session}")
        
        # Initialize AWS clients
        if not self._init_aws_clients():
            print("❌ Cannot continue without AWS clients")
            return
        
        # 1. Capture Agent Core logs
        self.capture_agent_core_logs()
        
        # 2. Find and check DNS Lambda functions
        self.find_dns_lambda_functions()
        
        # 3. Test agent endpoint
        self.test_agent_endpoint()
        
        # 4. Generate final debug report
        self.generate_debug_report()

def main():
    """Main execution function"""
    try:
        debugger = DNSAgentDebugger()
        debugger.run_comprehensive_debug()
        
    except KeyboardInterrupt:
        print("\n🛑 Debug session interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")

if __name__ == "__main__":
    main()