#!/usr/bin/env python3
"""
Test script to run the DNS container with proper environment variables
"""

import subprocess
import json

def test_container_with_env():
    """Test the DNS container with environment variables set"""
    
    # Set environment variables for the container
    container_image = "818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.1.0"
    
    # Test with basic environment variables
    env_vars = [
        "-e", "ENV=dev",  # Set environment to dev
        "-e", "APP_CONFIG_PATH=/app",  # Config path points to /app where chatops_config.py exists
        "-e", "AWS_DEFAULT_REGION=us-east-1"  # Set AWS region
    ]
    
    # Test lambda handler execution
    cmd = [
        "docker", "run", "--rm"
    ] + env_vars + [
        "--entrypoint", "sh",
        container_image,
        "-c", "cd /app && python3 -c \"import lambda_handler; print('Lambda handler imported successfully')\""
    ]
    
    print("Testing container with environment variables...")
    print(f"Command: {' '.join(cmd)}")
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        
        print(f"Exit code: {result.returncode}")
        print(f"STDOUT: {result.stdout}")
        if result.stderr:
            print(f"STDERR: {result.stderr}")
            
        return result.returncode == 0
        
    except subprocess.TimeoutExpired:
        print("Command timed out")
        return False
    except Exception as e:
        print(f"Error running container: {e}")
        return False

def test_lambda_handler_directly():
    """Test the lambda handler function directly"""
    
    container_image = "818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.1.0"
    
    env_vars = [
        "-e", "ENV=dev",
        "-e", "APP_CONFIG_PATH=/app",
        "-e", "AWS_DEFAULT_REGION=us-east-1"
    ]
    
    # Test with a sample DNS lookup event
    test_event = {
        "domain": "google.com",
        "record_type": "A"
    }
    
    cmd = [
        "docker", "run", "--rm"
    ] + env_vars + [
        "--entrypoint", "sh",
        container_image,
        "-c", f"cd /app && python3 -c \"import lambda_handler; import json; event = {json.dumps(test_event)}; result = lambda_handler.lambda_handler(event, None); print('Result:', result)\""
    ]
    
    print("\nTesting lambda handler with DNS lookup...")
    print(f"Test event: {test_event}")
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        
        print(f"Exit code: {result.returncode}")
        print(f"STDOUT: {result.stdout}")
        if result.stderr:
            print(f"STDERR: {result.stderr}")
            
        return result.returncode == 0
        
    except subprocess.TimeoutExpired:
        print("Command timed out")
        return False
    except Exception as e:
        print(f"Error running lambda handler test: {e}")
        return False

if __name__ == "__main__":
    print("=== Testing DNS Container Fix ===")
    
    # Test 1: Basic import
    success1 = test_container_with_env()
    
    # Test 2: Lambda handler execution
    success2 = test_lambda_handler_directly()
    
    print(f"\n=== Results ===")
    print(f"Basic import test: {'PASS' if success1 else 'FAIL'}")
    print(f"Lambda handler test: {'PASS' if success2 else 'FAIL'}")
    
    if success1 and success2:
        print("\n✅ Container is working! Environment variables are correctly set.")
        print("Next step: Update the Agent Core Runtime configuration with these environment variables.")
    else:
        print("\n❌ Container still has issues. Need to investigate further.")