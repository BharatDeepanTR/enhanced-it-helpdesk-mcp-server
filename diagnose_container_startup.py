#!/usr/bin/env python3
"""
Agent Core Runtime Container Startup Diagnostic
==============================================

This script diagnoses why the DNS Agent Core Runtime container
is not starting properly and provides specific fixes.

Runtime ID: a208194_chatops_route_dns_lookup-Zg3E6G5ZDV
ECR Repository: dns-lookup-service
"""

import boto3
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional

class ContainerStartupDiagnostic:
    """Container startup diagnostic tool"""
    
    def __init__(self):
        """Initialize the diagnostic tool"""
        self.region = 'us-east-1'
        self.runtime_id = 'a208194_chatops_route_dns_lookup-Zg3E6G5ZDV'
        self.ecr_repo = 'dns-lookup-service'
        self.account_id = '818565325759'
        
        self.setup_logging()
        self._init_aws_clients()
        
        self.logger.info("🔍 Container Startup Diagnostic initialized")

    def setup_logging(self):
        """Configure logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger('ContainerDiagnostic')

    def _init_aws_clients(self):
        """Initialize AWS clients"""
        try:
            self.ecr = boto3.client('ecr', region_name=self.region)
            self.logs = boto3.client('logs', region_name=self.region)
            self.sts = boto3.client('sts', region_name=self.region)
            
            identity = self.sts.get_caller_identity()
            self.logger.info(f"🔐 Account: {identity.get('Account')}")
            
        except Exception as e:
            self.logger.error(f"❌ AWS client initialization failed: {str(e)}")
            raise

    def check_latest_container_image(self) -> Dict[str, Any]:
        """Check the latest container image details"""
        self.logger.info("🐳 Analyzing latest container image...")
        
        try:
            # Get image details
            response = self.ecr.describe_images(
                repositoryName=self.ecr_repo,
                maxResults=10
            )
            
            images = response.get('imageDetails', [])
            if not images:
                return {'status': 'error', 'message': 'No images found'}
            
            # Sort by push date
            images.sort(key=lambda x: x.get('imagePushedAt', datetime.min), reverse=True)
            latest_image = images[0]
            
            print("\n" + "="*80)
            print("🐳 LATEST CONTAINER IMAGE ANALYSIS")
            print("="*80)
            
            # Image details
            image_digest = latest_image.get('imageDigest', 'N/A')
            push_date = latest_image.get('imagePushedAt', 'N/A')
            image_size = latest_image.get('imageSizeInBytes', 0)
            tags = latest_image.get('imageTags', [])
            
            print(f"📦 Repository: {self.ecr_repo}")
            print(f"🔷 Digest: {image_digest}")
            print(f"📅 Pushed: {push_date}")
            print(f"📊 Size: {image_size / (1024*1024):.1f} MB")
            print(f"🏷️ Tags: {tags if tags else ['<no-tag>']}")
            
            # Check image manifest for issues
            try:
                manifest_response = self.ecr.get_download_url_for_layer(
                    repositoryName=self.ecr_repo,
                    layerDigest=image_digest
                )
                print("✅ Image manifest accessible")
            except Exception as e:
                if "does not exist" in str(e):
                    print("❌ Image manifest not accessible")
                else:
                    print(f"⚠️ Manifest check failed: {str(e)[:100]}")
            
            return {
                'status': 'success',
                'image_digest': image_digest,
                'push_date': push_date,
                'size_mb': image_size / (1024*1024),
                'tags': tags
            }
            
        except Exception as e:
            self.logger.error(f"❌ Container image analysis failed: {str(e)}")
            return {'status': 'error', 'message': str(e)}

    def check_runtime_logs_detailed(self) -> Dict[str, Any]:
        """Check runtime logs for startup errors"""
        self.logger.info("📋 Analyzing runtime logs in detail...")
        
        try:
            log_group = f"/aws/vendedlogs/bedrock-agentcore/runtime/APPLICATION_LOGS/{self.runtime_id}"
            
            print("\n" + "="*80)
            print("📋 RUNTIME LOGS DETAILED ANALYSIS")
            print("="*80)
            
            # Get log streams
            streams_response = self.logs.describe_log_streams(
                logGroupName=log_group,
                orderBy='LastEventTime',
                descending=True,
                limit=10
            )
            
            streams = streams_response.get('logStreams', [])
            print(f"📄 Found {len(streams)} log streams")
            
            total_events = 0
            error_count = 0
            startup_errors = []
            
            for i, stream in enumerate(streams, 1):
                stream_name = stream.get('logStreamName')
                last_event = stream.get('lastEventTime', 0)
                event_count = stream.get('storedBytes', 0)
                
                print(f"\n📄 Stream {i}: {stream_name}")
                print(f"   Last Event: {datetime.fromtimestamp(last_event/1000) if last_event else 'None'}")
                print(f"   Stored Bytes: {event_count}")
                
                # Get recent events from this stream
                try:
                    events_response = self.logs.get_log_events(
                        logGroupName=log_group,
                        logStreamName=stream_name,
                        startTime=int((datetime.now() - timedelta(hours=24)).timestamp() * 1000),
                        limit=100
                    )
                    
                    events = events_response.get('events', [])
                    total_events += len(events)
                    
                    # Look for startup errors
                    for event in events:
                        message = event.get('message', '')
                        timestamp = event.get('timestamp', 0)
                        
                        if any(keyword in message.lower() for keyword in [
                            'error', 'fail', 'exception', 'timeout', 'startup', 'init'
                        ]):
                            error_count += 1
                            startup_errors.append({
                                'timestamp': datetime.fromtimestamp(timestamp/1000),
                                'message': message[:200]
                            })
                            
                            if len(startup_errors) <= 5:  # Show only first 5 errors
                                print(f"   🚨 ERROR: {message[:100]}...")
                    
                except Exception as e:
                    print(f"   ⚠️ Could not read events: {str(e)[:50]}")
            
            print(f"\n📊 SUMMARY:")
            print(f"   Total Events: {total_events}")
            print(f"   Error Events: {error_count}")
            
            if startup_errors:
                print(f"\n🚨 RECENT STARTUP ERRORS:")
                for error in startup_errors[:3]:
                    print(f"   {error['timestamp']}: {error['message']}")
            else:
                print(f"\n✅ No obvious startup errors found")
            
            return {
                'status': 'success',
                'total_events': total_events,
                'error_count': error_count,
                'startup_errors': startup_errors
            }
            
        except Exception as e:
            print(f"❌ Log analysis failed: {str(e)}")
            return {'status': 'error', 'message': str(e)}

    def check_container_configuration(self) -> Dict[str, Any]:
        """Check container configuration issues"""
        self.logger.info("🔧 Checking container configuration...")
        
        print("\n" + "="*80)
        print("🔧 CONTAINER CONFIGURATION CHECK")
        print("="*80)
        
        # Check ECR repository configuration
        try:
            repo_response = self.ecr.describe_repositories(
                repositoryNames=[self.ecr_repo]
            )
            
            repo = repo_response['repositories'][0]
            
            print(f"📦 Repository Configuration:")
            print(f"   Name: {repo.get('repositoryName')}")
            print(f"   URI: {repo.get('repositoryUri')}")
            print(f"   Created: {repo.get('createdAt')}")
            print(f"   Image Scan: {'✅ Enabled' if repo.get('imageScanningConfiguration', {}).get('scanOnPush') else '❌ Disabled'}")
            print(f"   Lifecycle Policy: {'✅ Set' if repo.get('lifecyclePolicyText') else '❌ None'}")
            
            # Check repository permissions
            try:
                policy_response = self.ecr.get_repository_policy(
                    repositoryName=self.ecr_repo
                )
                print(f"   Repository Policy: ✅ Set")
            except self.ecr.exceptions.RepositoryPolicyNotFoundException:
                print(f"   Repository Policy: ⚠️ Not Set")
            
        except Exception as e:
            print(f"❌ Repository check failed: {str(e)}")
        
        # Common container startup issues
        print(f"\n🔍 COMMON STARTUP FAILURE PATTERNS:")
        print(f"   1. Missing or incorrect ENTRYPOINT")
        print(f"   2. Application code syntax errors")
        print(f"   3. Missing dependencies or libraries")
        print(f"   4. Incorrect file permissions")
        print(f"   5. Port binding issues")
        print(f"   6. Memory/resource constraints")
        
        return {'status': 'success'}

    def generate_fix_recommendations(self, image_info: Dict, logs_info: Dict) -> None:
        """Generate specific fix recommendations"""
        
        print("\n" + "="*80)
        print("🔧 CONTAINER STARTUP FIX RECOMMENDATIONS")
        print("="*80)
        
        print("🎯 IMMEDIATE ACTIONS:")
        
        # Based on image analysis
        if image_info.get('status') == 'success':
            image_age = datetime.now() - image_info.get('push_date', datetime.min)
            if image_age.days > 7:
                print("   1. 📦 REBUILD CONTAINER: Image is older than 7 days")
                print("      • Pull latest base image updates")
                print("      • Rebuild with latest dependencies")
                
            if image_info.get('size_mb', 0) < 10:
                print("   2. ⚠️ SUSPICIOUS IMAGE SIZE: Very small container image")
                print("      • Check if all files were included in build")
                print("      • Verify build process completed successfully")
        
        # Based on logs analysis
        if logs_info.get('total_events', 0) == 0:
            print("   3. 🚨 NO APPLICATION LOGS: Container not starting at all")
            print("      • Check container ENTRYPOINT and CMD")
            print("      • Verify application entry point exists")
            print("      • Test container locally with docker run")
        
        elif logs_info.get('error_count', 0) > 0:
            print("   4. 🔍 STARTUP ERRORS DETECTED: Check specific error messages")
            print("      • Fix application code errors")
            print("      • Install missing dependencies")
            print("      • Check environment variables")
        
        print(f"\n💡 TESTING STEPS:")
        print(f"   1. Test container locally:")
        print(f"      docker pull {self.account_id}.dkr.ecr.{self.region}.amazonaws.com/{self.ecr_repo}:latest")
        print(f"      docker run -it --rm {self.account_id}.dkr.ecr.{self.region}.amazonaws.com/{self.ecr_repo}:latest")
        print(f"   ")
        print(f"   2. Check container logs:")
        print(f"      docker logs <container_id>")
        print(f"   ")
        print(f"   3. Verify entry point:")
        print(f"      docker inspect {self.account_id}.dkr.ecr.{self.region}.amazonaws.com/{self.ecr_repo}:latest")
        
        print(f"\n🔧 AGENT CORE RUNTIME FIXES:")
        print(f"   • Ensure container exposes the correct port")
        print(f"   • Verify health check endpoint works")
        print(f"   • Check runtime resource allocation")
        print(f"   • Compare with working account agent container")

    def run_comprehensive_diagnostic(self):
        """Run complete container startup diagnostic"""
        print("\n🔍 CONTAINER STARTUP COMPREHENSIVE DIAGNOSTIC")
        print("="*70)
        print(f"🕒 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🎯 Runtime ID: {self.runtime_id}")
        print(f"📦 ECR Repository: {self.ecr_repo}")
        print("="*70)
        
        # 1. Check container image
        image_info = self.check_latest_container_image()
        
        # 2. Check runtime logs
        logs_info = self.check_runtime_logs_detailed()
        
        # 3. Check configuration
        config_info = self.check_container_configuration()
        
        # 4. Generate recommendations
        self.generate_fix_recommendations(image_info, logs_info)
        
        print("\n" + "="*80)
        print("✅ CONTAINER STARTUP DIAGNOSTIC COMPLETE")
        print("="*80)
        print("🎯 Focus on the HIGH PRIORITY items above")
        print("💡 Test container locally before Agent Core deployment")

def main():
    """Main execution function"""
    try:
        diagnostic = ContainerStartupDiagnostic()
        diagnostic.run_comprehensive_diagnostic()
        
    except KeyboardInterrupt:
        print("\n🛑 Diagnostic interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")

if __name__ == "__main__":
    main()