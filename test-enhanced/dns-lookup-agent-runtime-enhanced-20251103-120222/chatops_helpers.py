#
# Copyright 2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
import os, json, logging, configparser
import boto3
import time
import pprint
import chatops_config

logger = logging.getLogger()
logger.setLevel(logging.DEBUG)

# Initialize app at global scope for reuse across invocations
app = None

def get_slot_values(slot_values, intent_request):
    if slot_values is None:
        slot_values = {key: None for key in chatops_config.SLOT_CONFIG}
    
    slots = intent_request['currentIntent']['slots']

    for key,config in chatops_config.SLOT_CONFIG.items():
        slot_values[key] = slots.get(key)
        logger.debug('<<chatops>> retrieving slot value for %s = %s', key, slot_values[key])
        if slot_values[key]:
            if config.get('type', chatops_config.ORIGINAL_VALUE) == chatops_config.TOP_RESOLUTION:
                # get the resolved slot name of what the user said/typed
                if len(intent_request['currentIntent']['slotDetails'][key]['resolutions']) > 0:
                    slot_values[key] = intent_request['currentIntent']['slotDetails'][key]['resolutions'][0]['value']
                else:
                    errorMsg = chatops_config.SLOT_CONFIG[key].get('error', 'Sorry, I don\'t understand "{}".')
                    raise chatops_config.SlotError(errorMsg.format(slots.get(key)))
                
            # slot_values[key] = userexits.post_process_slot_value(key, slot_values[key])
    
    return slot_values


def get_remembered_slot_values(slot_values, session_attributes):
    logger.debug('<<chatops>> get_remembered_slot_values() - session_attributes: %s', session_attributes)

    str = session_attributes.get('rememberedSlots')
    remembered_slot_values = json.loads(str) if str is not None else {key: None for key in chatops_config.SLOT_CONFIG}
    
    if slot_values is None:
        slot_values = {key: None for key in chatops_config.SLOT_CONFIG}
    
    logger.debug('<<chatops>> get_remembered_slot_values() - slot_values: %s', slot_values)
    logger.debug('<<chatops>> get_remembered_slot_values() - remembered_slot_values: %s', remembered_slot_values)
    for key,config in chatops_config.SLOT_CONFIG.items():
        if config.get('remember', False):
            logger.debug('<<chatops>> get_remembered_slot_values() - slot_values[%s] = %s', key, slot_values.get(key))
            logger.debug('<<chatops>> get_remembered_slot_values() - remembered_slot_values[%s] = %s', key, remembered_slot_values.get(key))
            if slot_values.get(key) is None:
                slot_values[key] = remembered_slot_values.get(key)
                
    return slot_values


def remember_slot_values(slot_values, session_attributes):
    if slot_values is None:
        slot_values = {key: None for key,config in chatops_config.SLOT_CONFIG.items() if config['remember']}
    session_attributes['rememberedSlots'] = json.dumps(slot_values)
    logger.debug('<<chatops>> Storing updated slot values: %s', slot_values)           
    return slot_values


def close(session_attributes, fulfillment_state, message):
    response = {
        'sessionAttributes': session_attributes,
        'dialogAction': {
            'type': 'Close',
            'fulfillmentState': fulfillment_state,
            'message': message
        }
    }
    
    logger.debug('<<chatops>> "Lambda fulfillment function response = ' + json.dumps(response)) 

    return response


def confirm(session_attributes, intent_name, slots, message):
    response = {
        'sessionAttributes': session_attributes,
        'dialogAction': {
            'type': 'ConfirmIntent',
            'intentName': intent_name,
            'slots': slots,
            'message': message
        }
    }

    logger.debug('<<chatops>> "Lambda confirmation function response = ' + json.dumps(response)) 

    return response


def elicit_slot(session_attributes, intent_name, slot_to_elicit, slots, message):
    response = {
        'sessionAttributes': session_attributes,
        'dialogAction': {
            'type': 'ElicitSlot',
            'intentName': intent_name,
            'slotToElicit': slot_to_elicit,
            'slots': slots,
            'message': message
        }
    }

    logger.debug('<<chatops>> "Lambda elicit_slot function response = ' + json.dumps(response)) 

    return response


def elicit_slot_with_choices(session_attributes, intent_name, slot_to_elicit, slots, choices_title, choices_text, choices_dict, message):
    response = {
        'sessionAttributes': session_attributes,
        'dialogAction': {
            'type': 'ElicitSlot',
            'intentName': intent_name,
            'slotToElicit': slot_to_elicit,
            'slots': slots,
            'message': message,
            'responseCard': {
                'version': 1,
                'contentType': 'application/vnd.amazonaws.card.generic',
                'genericAttachments': [
                    {
                        'title': choices_title,
                        'buttons': [{'text': choices_text[key], 'value': key} for key in choices_dict]
                    } 
                ] 
            }
        }
    }

    logger.debug('<<chatops>> "Lambda elicit_slot_with_choices function response =' + json.dumps(response)) 

    return response


def increment_counter(session_attributes, counter):
    counter_value = session_attributes.get(counter, '0')

    if counter_value: count = int(counter_value) + 1
    else: count = 1
    
    session_attributes[counter] = count

    return count

def get_ssm_secrets():
    global app
    if app is None:
        logger.info("<<chatops_helpers.get_ssm_secrets>> Loading config and creating new SSMCacheApp...")
        env = os.environ['ENV']
        full_config_path = os.environ['APP_CONFIG_PATH']+'/'
        config = load_config(full_config_path)
        app = SSMCacheApp(config)
    else:
        config = app.get_config()
    return config


class SSMCacheApp:
    def __init__(self, config):
        self.config = config

    def get_config(self):
        return self.config


def load_config(ssm_parameter_path):
    logger.debug("<<chatops_helpers.load_config>> calling ssmClient = client = boto3.client('ssm', region_name='us-east-1')")
    client = boto3.client('ssm', region_name='us-east-1')    # is region needed?
    logger.debug("<<chatops_helpers.load_config>> calling paginator = client.get_paginator('get_parameters_by_path')")
    paginator = client.get_paginator('get_parameters_by_path')

    configuration = configparser.ConfigParser()
    #Initializing dictionary object to store key names and values
    config_dict={}
    new_dict_open={}
    new_dict_close={}
    new_open={}
    new_close={}
    new_service={}
    new_dict_service_issues={}
    value1={}
    counter=0
    # Get all parameters for this app
    logger.info("<<chatops_helpers.load_config>>: calling page_iterator = paginator.paginate(Path=full_config_path...")
    page_iterator = paginator.paginate(Path=ssm_parameter_path,
            Recursive=True,
            WithDecryption=True)
    for page in page_iterator:
        temp_list=page['Parameters']
        logger.info("temp list is")
        logger.info(temp_list)
        for item in temp_list:
            if any(pattern in item['Name'] for pattern in ["IHN-Accounts-by", "-aws-issues","aws-service-"]):
                config_dict["".join(item['Name'].split('/')[-2:])] = item['Value']
            else:
                config_dict[item['Name'].split('/')[-1]]=item['Value']
        for key,value in config_dict.items():
            if(key.startswith('open')):
                value1=json.loads(value)
                new_dict_open.update(value1)
            elif(key.startswith('close')):
                counter+=1
                value1=json.loads(value)
                new_dict_close.update(value1)
            elif(key.startswith('aws-service-issues')):
                value1=json.loads(value)
                new_dict_service_issues.update(value1)
        new_service=json.dumps(new_dict_service_issues)
        new_open=json.dumps(new_dict_open)
        new_close=json.dumps(new_dict_close)
        config_dict['open-issue']=new_open
        config_dict['closed-issue']=new_close
        config_dict['aws-service-issues']=new_service
    logger.info("<<chatops_helpers.load_config: SSM response = REDACTED")
    logger.info("counter is {} ".format(counter))
    logger.info("config_dict closed issues{}".format(new_close))
    print("config_dict from SSM response is {}".format(config_dict.keys()))
    print("config_dict from SSM response is {}".format(config_dict.values()))
    return config_dict


