#!/usr/bin/env python3
"""
Lambda Function Syntax Fix

The Lambda function a208194-chatops_application_details_intent has a syntax error:
- Line 46: except E:  # This is invalid - 'E' is not defined

This script provides the corrected exception handling patterns.
"""

import json
import requests
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_application_details_from_api(app_asset_id):
    """
    Fixed version of the function with proper exception handling
    """
    try:
        # Your API call logic here
        # Example structure based on common patterns:
        api_url = "YOUR_API_ENDPOINT"  # Replace with actual endpoint
        headers = {"x-api-key": "YOUR_API_KEY"}  # Replace with actual headers
        
        response = requests.get(f"{api_url}/{app_asset_id}", headers=headers)
        response.raise_for_status()
        
        return response.json()
        
    except requests.exceptions.RequestException as e:
        # ✅ FIXED: Use specific exception instead of undefined 'E'
        logger.error(f"API request failed for asset {app_asset_id}: {str(e)}")
        raise
    except json.JSONDecodeError as e:
        # ✅ Handle JSON parsing errors
        logger.error(f"Failed to parse JSON response for asset {app_asset_id}: {str(e)}")
        raise
    except Exception as e:
        # ✅ General exception handler
        logger.error(f"Unexpected error getting application details for asset {app_asset_id}: {str(e)}")
        raise

def dispatch(event):
    """
    Main dispatch function with proper error handling
    """
    try:
        # Extract asset_id from event
        if isinstance(event, dict):
            app_asset_id = event.get('asset_id') or event.get('app_asset_id')
        else:
            app_asset_id = str(event)
        
        if not app_asset_id:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing asset_id parameter'})
            }
        
        # Get application details
        app_details = get_application_details_from_api(app_asset_id)
        
        return {
            'statusCode': 200,
            'body': json.dumps(app_details)
        }
        
    except Exception as e:
        logger.error(f"Error in dispatch: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Internal server error',
                'message': str(e)
            })
        }

def lambda_handler(event, context):
    """
    AWS Lambda entry point with proper error handling
    """
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        return dispatch(event)
    except Exception as e:
        logger.error(f"Lambda handler error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Lambda execution failed',
                'message': str(e)
            })
        }

# Example of common exception handling patterns for Lambda functions
EXCEPTION_PATTERNS = """
COMMON LAMBDA EXCEPTION HANDLING PATTERNS:
==========================================

❌ WRONG:
except E:  # 'E' is not defined

✅ CORRECT OPTIONS:

1. Specific exceptions:
   except requests.exceptions.RequestException as e:
   except ValueError as e:
   except KeyError as e:
   except json.JSONDecodeError as e:

2. Multiple exceptions:
   except (requests.exceptions.RequestException, ValueError) as e:

3. General exception (use sparingly):
   except Exception as e:

4. HTTP-specific exceptions:
   except requests.exceptions.HTTPError as e:
   except requests.exceptions.Timeout as e:
   except requests.exceptions.ConnectionError as e:

LAMBDA DEPLOYMENT FIX:
======================
1. Update the Lambda function code with proper exception handling
2. Test locally first
3. Deploy the corrected code
4. Verify with direct Lambda invocation
"""

if __name__ == "__main__":
    print(EXCEPTION_PATTERNS)
    
    # Test the fixed function
    test_event = {"asset_id": "a208194"}
    result = lambda_handler(test_event, None)
    print(f"Test result: {result}")