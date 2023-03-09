#!/bin/bash
url=http://127.0.0.1/api_jsonrpc.php
user=api
password=zabbix

# get authorization token
auth=$(curl -ks -X POST -H 'Content-Type: application/json-rpc' -d \
"
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

echo
echo auth key:
echo $auth
echo

echo obtain all unrechable hosts
unreach=$(curl -ks --location --request POST $url \
--header 'Content-Type: application/json' -d "
{
    \"jsonrpc\": \"2.0\",
    \"method\": \"host.get\",
    \"params\": {
        \"output\": [\"hostid\",\"host\",\"lastaccess\"],
        \"filter\": {\"available\": \"2\",\"status\":\"0\"}    },
    \"auth\": \"$auth\",
    \"id\": 1
}
" | jq -r '.result[].hostid' | sed "s|$|,|" | tr -cd '[:print:]' | sed "s|.$||")
echo $unreach
echo

echo delete
curl -ks -X POST -H 'Content-Type: application/json-rpc' -d " \
{
    \"jsonrpc\": \"2.0\",
    \"method\": \"host.delete\",
    \"params\": [ $unreach ],
    \"auth\": \"$auth\",
    \"id\": 1
}
" $url


echo
echo logout user:
curl -ks -X POST -H 'Content-Type: application/json-rpc' -d " \
{
    \"jsonrpc\": \"2.0\",
    \"method\": \"user.logout\",
    \"params\": [],
    \"id\": 1,
    \"auth\": \"$auth\"
}
" $url
echo
echo
