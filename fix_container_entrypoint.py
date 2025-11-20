#!/usr/bin/env python3
"""
Fix Container Entrypoint Issue
===============================

The container is trying to execute "lambda_handler.lambda_handler" directly
instead of running it with Python. This script helps diagnose and fix the issue.
"""

import subprocess
import json
import os
from datetime import datetime

def inspect_container():
    """Inspect the container to understand its configuration"""
    
    print("🔍 CONTAINER ENTRYPOINT DIAGNOSTIC")
    print("=" * 60)
    print(f"🕒 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    image_name = "818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.1.0"
    
    try:
        # Inspect the image configuration
        print("1️⃣ INSPECTING DOCKER IMAGE...")
        result = subprocess.run([
            'docker', 'inspect', image_name
        ], capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0:
            config = json.loads(result.stdout)[0]
            
            print("✅ Image inspection successful")
            print()
            
            # Extract key configuration
            container_config = config.get('ContainerConfig', {})
            config_section = config.get('Config', {})
            
            print("📋 CONTAINER CONFIGURATION:")
            print("-" * 40)
            
            # Check EntryPoint
            entrypoint = config_section.get('Entrypoint', [])
            cmd = config_section.get('Cmd', [])
            working_dir = config_section.get('WorkingDir', '')
            
            print(f"🚪 Entrypoint: {entrypoint}")
            print(f"⚙️ Cmd: {cmd}")
            print(f"📁 WorkingDir: {working_dir}")
            print(f"👤 User: {config_section.get('User', 'root')}")
            
            # Environment variables
            env_vars = config_section.get('Env', [])
            print(f"🌍 Environment Variables:")
            for env_var in env_vars:
                print(f"   {env_var}")
            
            print()
            
            # Identify the problem
            print("2️⃣ PROBLEM ANALYSIS:")
            print("-" * 30)
            
            if entrypoint and 'lambda_handler.lambda_handler' in str(entrypoint):
                print("❌ FOUND THE ISSUE:")
                print("   Container is trying to execute 'lambda_handler.lambda_handler' directly")
                print("   This should be run with Python instead")
                print()
                
                print("🔧 SOLUTION:")
                print("   The ENTRYPOINT should be:")
                print("   ['python', '-m', 'awslambdaric', 'lambda_handler.lambda_handler']")
                print("   OR")
                print("   ['python', 'lambda_handler.py']")
            
        else:
            print(f"❌ Failed to inspect image: {result.stderr}")
            
    except Exception as e:
        print(f"❌ Error inspecting container: {str(e)}")

def check_container_contents():
    """Check what's inside the container"""
    
    print("\n3️⃣ CHECKING CONTAINER CONTENTS...")
    print("-" * 40)
    
    image_name = "818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.1.0"
    
    try:
        # Run container with sh to explore contents
        print("📂 Listing container files:")
        result = subprocess.run([
            'docker', 'run', '--rm', '--entrypoint', 'sh', 
            image_name, '-c', 'ls -la'
        ], capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0:
            print(result.stdout)
        else:
            print(f"❌ Failed to list files: {result.stderr}")
        
        # Check for Python files
        print("🐍 Looking for Python files:")
        result = subprocess.run([
            'docker', 'run', '--rm', '--entrypoint', 'sh',
            image_name, '-c', 'find . -name "*.py" | head -10'
        ], capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0:
            print(result.stdout)
        else:
            print(f"❌ Failed to find Python files: {result.stderr}")
        
        # Check if lambda_handler.py exists
        print("🔍 Checking for lambda_handler.py:")
        result = subprocess.run([
            'docker', 'run', '--rm', '--entrypoint', 'sh',
            image_name, '-c', 'ls -la lambda_handler.py 2>/dev/null || echo "lambda_handler.py not found"'
        ], capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0:
            print(result.stdout)
        
    except Exception as e:
        print(f"❌ Error checking container contents: {str(e)}")

def create_fixed_dockerfile():
    """Create a fixed Dockerfile"""
    
    print("\n4️⃣ CREATING FIXED DOCKERFILE...")
    print("-" * 40)
    
    dockerfile_content = '''# Fixed Dockerfile for DNS Lookup Service
FROM public.ecr.aws/lambda/python:3.11

# Copy function code
COPY . ${LAMBDA_TASK_ROOT}

# Install dependencies if requirements.txt exists
RUN if [ -f requirements.txt ]; then pip install -r requirements.txt; fi

# Set the CMD to your handler (could also be done as a parameter override)
CMD ["lambda_handler.lambda_handler"]
'''
    
    with open('Dockerfile.fixed', 'w') as f:
        f.write(dockerfile_content)
    
    print("📄 Created Dockerfile.fixed with correct configuration")
    print()
    print("🔧 TO FIX THE CONTAINER:")
    print("1. Use the Dockerfile.fixed as your Dockerfile")
    print("2. Rebuild the container image")
    print("3. Push to ECR")
    print("4. Update Agent Core Runtime to use new image")
    print()
    
    # Also create a simple test script
    test_script = '''#!/usr/bin/env python3
"""
Test script to verify the Lambda handler works locally
"""

def test_lambda_handler():
    try:
        # Import the handler
        from lambda_handler import lambda_handler
        
        # Test event
        test_event = {
            "inputText": "What is the IP address of google.com?",
            "sessionId": "test-session-123"
        }
        
        # Test context (minimal)
        class TestContext:
            def get_remaining_time_in_millis(self):
                return 30000
        
        # Call the handler
        result = lambda_handler(test_event, TestContext())
        print("✅ Handler test successful!")
        print(f"📋 Result: {result}")
        
    except Exception as e:
        print(f"❌ Handler test failed: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_lambda_handler()
'''
    
    with open('test_lambda_handler.py', 'w') as f:
        f.write(test_script)
    
    print("📄 Created test_lambda_handler.py to test the handler locally")

def provide_immediate_fix():
    """Provide immediate fix instructions"""
    
    print("\n" + "=" * 60)
    print("🎯 IMMEDIATE FIX INSTRUCTIONS")
    print("=" * 60)
    
    print("""
🔧 QUICK FIX OPTIONS:

Option 1: Test with correct entrypoint
   docker run --rm --entrypoint python \\
     818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.1.0 \\
     -m awslambdaric lambda_handler.lambda_handler

Option 2: Run interactively to debug
   docker run -it --entrypoint sh \\
     818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.1.0

Option 3: Fix the Dockerfile (recommended)
   1. Use the Dockerfile.fixed created above
   2. Rebuild: docker build -t dns-lookup-service:fixed .
   3. Test: docker run --rm dns-lookup-service:fixed
   4. Push to ECR with new tag
   5. Update Agent Core Runtime configuration

🎯 ROOT CAUSE:
   The container ENTRYPOINT is set incorrectly. It should use Python
   to run the Lambda handler, not try to execute it directly.
""")

def main():
    """Main execution function"""
    
    try:
        inspect_container()
        check_container_contents()
        create_fixed_dockerfile()
        provide_immediate_fix()
        
    except KeyboardInterrupt:
        print("\n🛑 Diagnostic interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")

if __name__ == "__main__":
    main()