#!/bin/bash
for table in $(mysql -sss -e "
SELECT CONCAT(table_name) FROM information_schema.tables 
WHERE table_schema='zabbix'
AND table_name NOT IN (
'history',
'history_uint',
'history_str',
'history_text',
'history_log',
'trends',
'trends_uint'
)
order by data_free desc;
")
do
mysql zabbix -e "OPTIMIZE TABLE $table;"
done

