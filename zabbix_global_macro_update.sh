#!/bin/bash
url=http://127.0.0.1/api_jsonrpc.php
user=api
password=zabbix
macro=$1
value=$2

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

# get global user macro id
id=$(curl -s -X POST \
-H 'Content-Type: application/json-rpc' \
-d " \
{
    \"jsonrpc\": \"2.0\",
    \"method\": \"usermacro.get\",
    \"params\": {
        \"output\": [\"globalmacroid\"],
        \"globalmacro\": true,
        \"filter\":{\"macro\": \"$macro\"}
    },
    \"auth\": \"$auth\",
    \"id\": 1
}
" $url | jq -r ".result[].globalmacroid") 

# update
curl -s -X POST \
-H 'Content-Type: application/json-rpc' \
-d " \
{
    \"jsonrpc\": \"2.0\",
    \"method\": \"usermacro.updateglobal\",
    \"params\": {
        \"globalmacroid\": \"$id\",
        \"value\": \"$value\"
    },
    \"auth\": \"$auth\",
    \"id\": 1
}
" $url

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
" $url
