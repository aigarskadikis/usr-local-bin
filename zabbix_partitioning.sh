#!/bin/bash
# (auth is in ~/.my.cnf)

# define partition maintenance command
command="CALL partition_maintenance_all('zabbix');"

# perform partition maintenance to drop all rolloff data
mysql zabbix -e "$command"

