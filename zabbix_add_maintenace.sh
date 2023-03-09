#!/bin/bash
url=http://127.0.0.1/api_jsonrpc.php
user=Admin
password=zabbix
start_time=$(date +%s)
end_time=$((start_time+86400)) #now + 1 day
hostname=$1

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

# get host id
id=$(curl -s -X POST \
-H 'Content-Type: application/json-rpc' \
-d " \
{
    \"jsonrpc\": \"2.0\",
    \"method\": \"host.get\",
    \"params\": {
        \"output\": [\"hostid\"],
        \"filter\":{\"host\": \"$hostname\"}
    },
    \"auth\": \"$auth\",
    \"id\": 1
}
" $url | jq -r ".result[].hostid")

# update
curl -s -X POST \
-H 'Content-Type: application/json-rpc' \
-d " \
{
    \"jsonrpc\": \"2.0\",
    \"method\": \"maintenance.create\",
    \"params\": {
        \"name\":\"Test API create2\",
        \"active_since\":\"$start_time\",
        \"active_till\":\"$end_time\",
        \"hostids\": [\"$id\"],
        \"timeperiods\":[{
            \"timeperiod_type\":0,
            \"period\":3600
        }]
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
