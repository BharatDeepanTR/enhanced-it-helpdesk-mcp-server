#
# Copyright 2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify,
# merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#


import logging
import json
import requests
from chatops_helpers import get_ssm_secrets
#from concurrent.futures import ThreadPoolExecutor
logger = logging.getLogger()
logger.setLevel(logging.DEBUG)
config = get_ssm_secrets()
AWSAccountAPI_withRef_URL = config.get('ACCT_REF_API')
APIKEY_2 = config.get('MGMT_APP_REF')
url_route53 = config.get("API_URL_ROUTE53")
#APIKEY = config.get("API_KEY_ROUTE53")
url_route53 = config.get('AWS_LZ_API')+'route53'
APIKEY = config.get('AWS_LZ_API_KEY')

# Removed Lex-specific functions: close(), formMsg(), get_slots()


'''
def fetch(session,url):
    headers = {"x-api-key" : api_key}
    if url == "https://m17lgwgwd9.execute-api.us-east-1.amazonaws.com/dev/route53":
        with session.get(url, headers=headers) as response:
            m = response.json()
            route53_records.append(m)
    elif url == "https://m17lgwgwd9.execute-api.us-east-1.amazonaws.com/dev/route53_mis":
        with session.get(url, headers=headers) as response:
            n = response.json()
            route53_records_mis.append(n)
    return route53_records
def make_parallel_api_connection():
    with ThreadPoolExecutor(max_workers=10) as exector:
        with requests.Session() as session:
            exector.map(fetch, [session]*2, [url1,url2])
            exector.shutdown(wait=True)
'''


def getAccountAliasAPIRequest(awsAccount):
    params = {"account_ref":awsAccount}
    response = httpPostRequest(AWSAccountAPI_withRef_URL, params, APIKEY_2)
    response = json.loads(response.content)
    logger.debug('response to get account alias')
    logger.debug(response)
    if (response['statusCode'] == 200) :
        if (response['Result']):
            results = response['Result']
            awsAccountAlias = results[awsAccount]['account_name']
            return awsAccountAlias
        else:
            return None
    else:
        return None


def httpPostRequest(url, params, apikey):
    logger.debug('starting httpPost call')
    try:
        payload=params
        head = {'x-api-key': apikey}
        response=requests.post(url, data=json.dumps(payload), headers=head)
        logger.debug('completed httpPost call')
        return response
    except Exception as err:
        logger.debug(str(err))
        raise Exception


def get_route53_records():
    url = url_route53
    API_KEY = APIKEY
    apiResponse = httpPostRequest_route53(url, API_KEY)
    status_code = apiResponse.status_code
    apiResponse = json.loads(apiResponse.content)
    return apiResponse, status_code


def httpPostRequest_route53(url,apikey):
    logger.info('starting httpPost call')
    try:
        payload= {}
        head = {'x-api-key': apikey}
        response=requests.post(url, data=json.dumps(payload), headers=head)
        logger.info('completed httpPost call')
        return response
    except Exception as err:
        logger.info(str(err))
        raise Exception(err)
    

def genai_implementation(user_content):
    layer_path = "/opt/function.txt" 
    file1 = open(layer_path, "r") 
    contents = json.loads(file1.read())
    url = contents['url']
    headers = contents['headers']
    system_content = '''Your a helpful assistant who exactly follows instructions mentioned here and executes all the actions without displaying any extra information.The results need to be in Tabular markdown format.Check if ResourceRecords or Alias_DNS_Name exists then display Account_Number,Hosted_Zone_Name,Type and ResourceRecords or Alias_DNS_Name as per the existence.Check if ResourceRecords or Alias_DNS_Name doesnot exists then display a message \"Invalid lookup reference dns name, No DNS name exists with this reference\"'''
    user_content = user_content
    payload = json.dumps({"messages": [
    {
      "role": "system",
      "content":system_content
    },
    {
      "role": "user",
      "content": user_content
    }
  ],
  "temperature": 0
})
    response = requests.post(url, headers=headers, data=payload)
    response = response.json()
    print(response)
    genai_response = response['choices'][0]['message']['content']
    return genai_response
    

def lookup_dns_record(dns_name):
    """
    Main function to lookup DNS records. Accepts DNS name directly.
    """
    logger.debug(f"Looking up DNS record for: {dns_name}")
    
    # Ensure DNS name ends with a dot
    if not dns_name.endswith('.'):
        dns_name = dns_name + "."
    
    logger.debug(f"Processing DNS value: {dns_name}")
    
    genai_input_list = []
    
    route53_records, status_code = get_route53_records()
    
    if not route53_records:
        return {
            'success': False,
            'message': "Something went wrong. Please try again after some time",
            'data': None
        }
    
    # Process DNS records
    for item in route53_records:
        for key, value in item['DNSrecords'].items():
            if key == dns_name:
                dns_details = value
                for detail_key, detail_value in value.items():
                    if detail_key == 'ResourceRecords': 
                        account_number = item['account_number']
                        hosted_zone_name = dns_details['Hosted_zone_name']
                        type_ = dns_details['Type']
                        ResourceRecords = detail_value
                        dict_values = {
                            'ResourceRecords': ResourceRecords,
                            'account_number': account_number,
                            'hosted_zone_name': hosted_zone_name,
                            'type': type_
                        }
                        genai_input_list.append(dict_values)
                    elif detail_key == 'Alias-DNS-Name':
                        account_number = item['account_number']
                        hosted_zone_name = dns_details['Hosted_zone_name']
                        type_ = dns_details['Type']
                        Alias_DNS_Name = detail_value 
                        dict_values = {
                            'Alias_DNS_Name': Alias_DNS_Name,
                            'account_number': account_number,
                            'hosted_zone_name': hosted_zone_name,
                            'type': type_
                        }
                        genai_input_list.append(dict_values)
    
    if genai_input_list:
        genai_input_str = str(genai_input_list)
        print(genai_input_str)
        genai_msg = genai_implementation(genai_input_str)
        return {
            'success': True,
            'message': genai_msg,
            'data': genai_input_list
        }
    else:
        return {
            'success': False,
            'message': f"Invalid lookup reference {dns_name.rstrip('.')}, No DNS name exists with this reference.",
            'data': None
        }
    '''
    # Note: Account alias functionality preserved but commented out for optional use
    awsAccountAlias = ''
    if awsAccountAlias == '':
        awsAccountAlias = getAccountAliasAPIRequest(account_number)
    
    # Alternative simple formatting (without GenAI):
    if ResourceRecords or Alias_DNS_Name:
        logger.info("msg is generating")
        msg = 'The lookup for **' + DNS_name_ + '** is:' + '\n\n'
        msg += '**Account_Number** : {}'.format(account_number) + '\n\n'
        msg += '**Hosted_Zone_Name** : {}'.format(hosted_zone_name)  + '\n\n'
        msg += '**Type** : {}'.format(type_)  + '\n\n'
        if ResourceRecords:
            msg += '**ResourceRecords** : {}'.format(str(ResourceRecords)) + '\n\n'
        elif Alias_DNS_Name:
            msg += '**Alias_DNS_Name** : {}'.format(Alias_DNS_Name) + '\n\n'
        logger.info(msg)
    '''


def lambda_handler(event, context):
    """
    Main lambda handler. Now accepts direct DNS lookup requests.
    Expected event format:
    {
        "dns_name": "example.com"
    }
    Or for backward compatibility with API Gateway:
    {
        "body": "{\"dns_name\": \"example.com\"}"
    }
    """
    logger.debug('---------------- START -------------------')
    logger.info(f"Received Event is : {event}")
    
    try:
        # Handle different event formats
        dns_name = None
        
        # Direct event format
        if 'dns_name' in event:
            dns_name = event['dns_name']
        
        # API Gateway format (body is JSON string)
        elif 'body' in event:
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
            dns_name = body.get('dns_name')
        
        # Legacy Lex format (for backward compatibility)
        elif 'currentIntent' in event and 'slots' in event['currentIntent']:
            dns_name = event['currentIntent']['slots'].get('DNS_record')
        
        if not dns_name:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'success': False,
                    'message': 'DNS name is required. Please provide dns_name in the request.',
                    'data': None
                })
            }
        
        # Perform DNS lookup
        result = lookup_dns_record(dns_name)
        
        # Return result in a standard format
        return {
            'statusCode': 200 if result['success'] else 404,
            'body': json.dumps(result),
            'headers': {
                'Content-Type': 'application/json'
            }
        }
        
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'success': False,
                'message': f'Internal server error: {str(e)}',
                'data': None
            }),
            'headers': {
                'Content-Type': 'application/json'
            }
        }