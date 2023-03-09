#!/bin/bash
url=http://127.0.0.1:140/api_jsonrpc.php
user=Admin
password=zabbix
triggerid=$1
limit=$2
time_till=$3

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

echo event ids to be closed:
close=$(curl -ks --location --request POST $url --header 'Content-Type: application/json' -d "
{
    \"jsonrpc\": \"2.0\",
    \"method\": \"problem.get\",
    \"params\": {
        \"objectids\": \"$triggerid\",
        \"output\": \"eventid\",
        \"time_till\": \"$time_till\",
        \"limit\": \"$limit\"
    },
    \"auth\": \"$auth\",
    \"id\": 1
}
" | jq -r '.result[].eventid' | sed "s|$|,|" | tr -cd '[:print:]' | sed "s|.$||")
echo $close
echo
# if there is a third argument

if [ ! -z "$close" ]; then
if [ ! -z "$4" ]; then
curl -k --location --request POST $url --header 'Content-Type: application/json' -d "
{
	\"jsonrpc\": \"2.0\",
	\"method\": \"event.acknowledge\",
	\"params\": {
		\"eventids\": [ $close ],
		\"action\": 1,
		\"message\": \"Problem resolved.\"
	},
	\"auth\": \"$auth\",
	\"id\": 1
}" $url
fi
fi
echo

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
