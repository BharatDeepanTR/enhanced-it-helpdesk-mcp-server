#!/usr/bin/env python3
"""
Test the DNS agent with corrected SSM path
"""

import subprocess

def test_with_correct_ssm_path():
    """Test the container with the correct SSM parameter path"""
    
    container_image = "818565325759.dkr.ecr.us-east-1.amazonaws.com/dns-lookup-service:v1.0.0"
    
    # Use the correct SSM path where the parameters actually exist
    env_vars = [
        "-e", "ENV=dev",
        "-e", "APP_CONFIG_PATH=/a208194/APISECRETS",  # Corrected path
        "-e", "AWS_DEFAULT_REGION=us-east-1"
    ]
    
    # Test lambda handler execution with AWS credentials from the environment
    cmd = [
        "docker", "run", "--rm"
    ] + env_vars + [
        "-e", f"AWS_ACCESS_KEY_ID={subprocess.getoutput('aws configure get aws_access_key_id')}",
        "-e", f"AWS_SECRET_ACCESS_KEY={subprocess.getoutput('aws configure get aws_secret_access_key')}",
        "-e", f"AWS_SESSION_TOKEN={subprocess.getoutput('aws configure get aws_session_token')}",
        "--entrypoint", "sh",
        container_image,
        "-c", "cd /app && python3 -c \"import container_handler; print('✅ Container handler imported successfully with correct SSM path!')\""
    ]
    
    print("Testing container with correct SSM parameter path...")
    print(f"SSM Path: /a208194/APISECRETS")
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        
        print(f"Exit code: {result.returncode}")
        print(f"STDOUT: {result.stdout}")
        if result.stderr:
            print(f"STDERR: {result.stderr}")
            
        if result.returncode == 0:
            print("\n🎉 SUCCESS! The container can start with the correct SSM path!")
            print("Next: Need to update Agent Core Runtime configuration to use correct environment variables.")
            return True
        else:
            print("\n❌ Still failing. Need to investigate further.")
            return False
            
    except subprocess.TimeoutExpired:
        print("Command timed out")
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False

if __name__ == "__main__":
    print("=== Testing DNS Container with Correct SSM Path ===")
    test_with_correct_ssm_path()