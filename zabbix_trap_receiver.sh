#!/bin/bash

# define destination
# it should be exactly the same as in
# 'grep SNMPTrapperFile= /etc/zabbix/zabbix_server.conf'
SNMPTrapperFile=/tmp/zabbix_traps.tmp

# content from stdin has been stored in a variable
all=$(tee)

# determine the IP address where the trap is comming from.
# the host with same IP address in Zabbix must exist as an SNMP device.
# the host must have at least 'snmptrap.fallback' item.
HOST=$(echo "$all" |\
grep "^UDP" |\
grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" |\
head -1)

# prepare the structure of content. trap should start with 'ZBXTRAP' 
# and represent the IP address of source device
str="ZBXTRAP $HOST
$all"

# add the content to file
echo "$str" | tee -a $SNMPTrapperFile
