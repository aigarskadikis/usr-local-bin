#!/bin/bash
url=http://127.0.0.1/api_jsonrpc.php
user=api
password=zabbix
START_TIME=$(date +%s)
END_TIME=$((start_time-86400)) #now + 1 day

# get authorization tokken
AUTH=$(curl -s -X POST \
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

# list all service and availability
curl -s -X POST \
-H 'Content-Type: application/json-rpc' \
-d " \
{
    \"jsonrpc\": \"2.0\",
    \"method\": \"service.getsla\",
    \"params\": {
        \"intervals\": [
            {
                \"from\": \"1352452201\",
                \"to\": \"1581417436\"
            }
        ]
    },
    \"auth\": \"$AUTH\",
    \"id\": 1
}
" $url | jq "."

# logout user
curl -s -X POST \
-H 'Content-Type: application/json-rpc' \
-d " \
{
    \"jsonrpc\": \"2.0\",
    \"method\": \"user.logout\",
    \"params\": [],
    \"id\": 1,
    \"auth\": \"$AUTH\"
}
" $url > /dev/null
