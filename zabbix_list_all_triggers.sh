#!/bin/bash
url=http://127.0.0.1/api_jsonrpc.php
user=api
password=zabbix
ZBX_HOST_NAME=$1

# get authorization tokken
auth=$(curl -s -X POST \
-H 'Content-Type: application/json-rpc' \
-d " \
{
 \"jsonrpc\": \"2.0\",
 \"method\": \"user.login\",
 \"params\": {
  \"user\": \"$user\",
  \"password\": \"$password\"
 },
 \"id\": 1,
 \"auth\": null
}
" $url | grep -E -o "([0-9a-f]{32,32})")

# list all triggers per one host
curl -s -X POST \
-H 'Content-Type: application/json-rpc' \
-d " \
{
	\"jsonrpc\": \"2.0\",
	\"method\": \"trigger.get\",
	\"params\": {
		\"output\": \"extend\",
		\"expandExpression\": \"1\",
		\"host\": \"$ZBX_HOST_NAME\"
	},
	\"auth\": \"$auth\",
	\"id\": 1
}
" $url | jq -r '.result[].expression'

# logout user
curl -s -X POST \
-H 'Content-Type: application/json-rpc' \
-d " \
{
    \"jsonrpc\": \"2.0\",
    \"method\": \"user.logout\",
    \"params\": [],
    \"id\": 1,
    \"auth\": \"$auth\"
}
" $url > /dev/null
