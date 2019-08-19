#!/usr/bin/env python3
import re
import json
import requests
from pygtail import Pygtail
from time import sleep

### Variables ###
#MailLogFilePath = './mail_pygtail.info'
MailLogFilePath = '/var/log/mail.info'
Period = 10 # Minutes;
#################


def GetMsgIDList(text):
    MsgIDList = []
    for line in text:
        if re.findall('status=(?!sent)',str(line)):
            MsgIDList.append( re.search(r'[0-9A-Z]{10}(?=:)',str(line)).group() )
    return MsgIDList

def GetMsgLog(MsgId, Text):
    result = []
    for line in Text:
        if MsgId in line:
            result.append(line)
    return result

def ParseMsgLog(MsgLog):
    ParsedLog = {}
    for line in MsgLog:
        if 'message-id' in line:
            match = re.search(r'(?<=message-id=<)[a-z0-9]{8}\-[a-z0-9]{4}\-[a-z0-9]{4}\-[a-z0-9]{4}\-[a-z0-9]{12}.*(?=>)',line)
            if match:
                ParsedLog['id'] = match.group()
            else:
                return None
        if 'said' in line:
            match = re.search(r'(?<=said:\s)(\d{1,})\s(.*)',line)
            if match:
                ParsedLog['errorCode'] = int(match.group(1))
                ParsedLog['errorMessage'] = match.group(2)
            else:
                return None
    return ParsedLog

def SendData(payload):
    url = "http://46.254.18.186:8080/message_status/"
    headers = {'content-type': 'application/json'}
    data = json.dumps(payload)
    responce = requests.post(url, data=data, headers=headers)
    return responce.status_code

#with open(MailLogFilePath,'rt') as file:
#    PostfixLogLines = file.readlines()
file = Pygtail(MailLogFilePath,full_lines=True)

while True:
    ParsedData = []

    PostfixLogLines = file.readlines()
    
    for MsgId in GetMsgIDList(PostfixLogLines):
        data = ParseMsgLog( GetMsgLog(MsgId,PostfixLogLines) )
        if data:
            ParsedData.append( data )
    # Send data
    SendData(ParsedData)
    # Sleep; We have to wait to let some data to collect
    sleep(Period*60)
    # break for test purposes only
    #break
