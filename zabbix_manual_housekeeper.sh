#!/bin/bash

date

SLEEP=1
DB=zabbix

# items.value_type:
# 0, ITEM_VALUE_TYPE_FLOAT - Float
# 1, ITEM_VALUE_TYPE_STR - Character
# 2, ITEM_VALUE_TYPE_LOG - Log
# 3, ITEM_VALUE_TYPE_UINT64 - Unsigned integer
# 4, ITEM_VALUE_TYPE_TEXT - Text

# delete historical data from tables:
# history, history_str, history_log, history_uint, history_text
for VALUE_TYPE in 0 1 2 3 4
do {

if [ $VALUE_TYPE -eq 0 ]; then TABLE="history"; fi
if [ $VALUE_TYPE -eq 1 ]; then TABLE="history_str"; fi
if [ $VALUE_TYPE -eq 2 ]; then TABLE="history_log"; fi
if [ $VALUE_TYPE -eq 3 ]; then TABLE="history_uint"; fi
if [ $VALUE_TYPE -eq 4 ]; then TABLE="history_text"; fi

echo ============
echo $TABLE
echo ============

# work with only items which has a 'd' (day) units. 's', 'h', 'm', 'w' 'y' will not be considered into account
HISTORY_PERIOD=$(
mysql $DB --raw --batch -N -e "
SELECT DISTINCT items.history
FROM items
JOIN hosts ON (hosts.hostid=items.hostid)
WHERE hosts.status IN (0,1)
AND items.value_type=$VALUE_TYPE
AND items.history LIKE '%d';
"
)

# go through each definition for example 3d, 7d, 14d
echo "$HISTORY_PERIOD" | \
grep -v "^$" | \
while IFS= read -r PERIOD
do {


PERIOD_FULL_NAME=$(echo "$PERIOD" | sed "s|d| DAY|")
# full name required for SQL DELETE command to use syntax:
# WHERE clock < UNIX_TIMESTAMP(NOW()-INTERVAL 3 DAY);
# practically a transformation happens: '3d' => '3 DAY'
echo $PERIOD_FULL_NAME

# collect all ITEMIDs which has a specific storage period
# hosts.status=0 - active hosts
# hosts.status=1 - disabled hosts
ALL_ITEM_IDS=$(
mysql $DB --raw --batch -N -e "
SET SESSION group_concat_max_len = 1000000;
SELECT GROUP_CONCAT(items.itemid)
FROM items
JOIN hosts ON (hosts.hostid=items.hostid)
WHERE hosts.status IN (0,1)
AND items.value_type=$VALUE_TYPE
AND items.history=\"$PERIOD\";
"
)

# launch delete operation
mysql $DB -e "DELETE FROM $TABLE 
WHERE itemid IN ($ALL_ITEM_IDS)
AND clock < UNIX_TIMESTAMP(NOW()-INTERVAL $PERIOD_FULL_NAME);"

sleep 30

} done


} done

