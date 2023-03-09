#!/bin/bash
# rebuid Zabbix DB partitions one by one and erase orphned metrics

CREDENTIALS=/root/.my.cnf
DATABASE=zabbix
NOW=$(date '+%s')

echo "
trends_uint
trends
history_uint
history
histroy_str
histroy_text
history_log
" | \
grep -v "^$" | \
while IFS= read -r TABLE
do {

echo $TABLE

mysql \
--defaults-file=$CREDENTIALS \
--database=$DATABASE \
--skip-column-names \
--execute="
SELECT PARTITION_NAME,PARTITION_DESCRIPTION FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_NAME=\"$TABLE\" AND PARTITION_NAME LIKE 'p%';
" | \
while IFS= read -r LINE
do {

TIMESTAMP=$(echo "$LINE" | grep -Eo "[0-9]+$")
PARTITION=$(echo "$LINE" | grep -Eo "^\S+")
echo $PARTITION comes from $TIMESTAMP

# optimize partitions which are older than 10d
[[ "$TIMESTAMP" -lt "$((NOW-864000))" ]] && \
mysql \
--defaults-file=$CREDENTIALS \
--database=$DATABASE \
--execute="
ALTER TABLE $TABLE REBUILD PARTITION $PARTITION;
"

} done

echo "===="

} done

