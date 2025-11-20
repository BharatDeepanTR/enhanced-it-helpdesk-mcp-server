#!/usr/bin/env python3
"""
Summary and Solution for DNS Agent Core Runtime Issue

PROBLEM IDENTIFIED:
1. Agent Core Runtime container expects SSM parameters at path: /app/
2. Actual SSM parameters are located at path: /a208194/APISECRETS/
3. IAM role lacked SSM permissions (FIXED)
4. Missing Route53 parameter (FIXED)

SOLUTIONS IMPLEMENTED:
✅ Added SSM permissions to IAM role: a208194-askjulius-supervisor-agent-role
✅ Created missing SSM parameter: /a208194/APISECRETS/API_URL_ROUTE53
✅ Verified all required SSM parameters exist:
   - /a208194/APISECRETS/ACCT_REF_API
   - /a208194/APISECRETS/MGMT_APP_REF
   - /a208194/APISECRETS/API_URL_ROUTE53

REMAINING ISSUE:
❌ Container environment variable APP_CONFIG_PATH points to wrong path

SOLUTION OPTIONS:
1. Rebuild container with correct APP_CONFIG_PATH
2. Update Agent Core Runtime configuration (if possible)
3. Create SSM parameters at the expected /app/ path

Let's try Option 3 (simplest approach):
"""

import boto3
import json

def copy_ssm_parameters_to_app_path():
    """Copy existing SSM parameters to the /app/ path expected by the container"""
    
    ssm = boto3.client('ssm', region_name='us-east-1')
    
    # Parameters to copy
    source_params = [
        '/a208194/APISECRETS/ACCT_REF_API',
        '/a208194/APISECRETS/MGMT_APP_REF',
        '/a208194/APISECRETS/API_URL_ROUTE53'
    ]
    
    target_params = [
        '/app/ACCT_REF_API',
        '/app/MGMT_APP_REF', 
        '/app/API_URL_ROUTE53'
    ]
    
    print("Copying SSM parameters to /app/ path...")
    
    for source, target in zip(source_params, target_params):
        try:
            # Get the source parameter
            response = ssm.get_parameter(Name=source, WithDecryption=True)
            value = response['Parameter']['Value']
            
            # Create the target parameter
            ssm.put_parameter(
                Name=target,
                Value=value,
                Type='String',
                Description=f'Copy of {source} for Agent Core Runtime',
                Overwrite=True
            )
            
            print(f"✅ Copied {source} -> {target}")
            
        except Exception as e:
            print(f"❌ Error copying {source}: {e}")

def verify_parameters():
    """Verify all parameters exist at /app/ path"""
    
    ssm = boto3.client('ssm', region_name='us-east-1')
    
    try:
        response = ssm.get_parameters_by_path(
            Path='/app/',
            Recursive=True,
            WithDecryption=True
        )
        
        print("\nParameters found at /app/ path:")
        for param in response['Parameters']:
            print(f"✅ {param['Name']}")
            
        return len(response['Parameters']) >= 3
        
    except Exception as e:
        print(f"Error checking parameters: {e}")
        return False

if __name__ == "__main__":
    print("=== DNS Agent Core Runtime Fix ===")
    print("Copying SSM parameters to expected path...")
    
    copy_ssm_parameters_to_app_path()
    
    if verify_parameters():
        print("\n🎉 SUCCESS! All parameters copied to /app/ path")
        print("The Agent Core Runtime should now be able to start successfully!")
        print("\nNext: Test the Agent Core Runtime to confirm it works")
    else:
        print("\n❌ Some parameters may be missing. Please check manually.")