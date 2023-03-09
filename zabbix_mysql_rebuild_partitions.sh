#!/bin/bash

# this is tested and works well on mysql 8.0.21
# in order to use 'mysql' and 'mysqldump' utility without password
# kindly install access characteristics in '/root/.my.cnf'

# do not keep history items
# SELECT itemid FROM history WHERE itemid IN (SELECT itemid FROM items WHERE history=0 AND value_type=0);
# SELECT itemid FROM history_str WHERE itemid IN (SELECT itemid FROM items WHERE history=0 AND value_type=1);
# SELECT itemid FROM history_log WHERE itemid IN (SELECT itemid FROM items WHERE history=0 AND value_type=2);
# SELECT itemid FROM history_uint WHERE itemid IN (SELECT itemid FROM items WHERE history=0 AND value_type=3);
# SELECT itemid FROM history_text WHERE itemid IN (SELECT itemid FROM items WHERE history=0 AND value_type=4);

date

DB=zabbix
DEST=/backup/mysql/zabbix/raw
mkdir -p "$DEST"
FROM=0
TO=0

echo "
history_str
history_log
history_text
trends_uint
trends
history
history_uint
" | 
grep -v "^$" | \
while IFS= read -r TABLE
do {

# make sure all is clear
mysql $DB -e "SET SESSION SQL_LOG_BIN=0; DELETE FROM $TABLE WHERE itemid NOT IN (SELECT itemid FROM items);"

# rename table to old so zabbix application is not locking the data
OLD=$(echo $TABLE|sed "s|$|_old|")
# temp table required for the online instance to store data while doing optimization
TMP=$(echo $TABLE|sed "s|$|_tmp|")

# do not distract environment while optimizing
echo "RENAME TABLE $TABLE TO $OLD;"
date
mysql $DB -e "RENAME TABLE $TABLE TO $OLD;"

# create similar table
echo "CREATE TABLE $TABLE LIKE $OLD;"
date
mysql $DB -e "CREATE TABLE $TABLE LIKE $OLD;"
date

# determine if table is using partitioning
PART_LIST_DETAILED=$(
mysql $DB -e " \
SHOW CREATE TABLE $TABLE\G
" | \
grep -Eo "PARTITION.*VALUES LESS THAN..[0-9]+"
)

# check if previous variable is emptu
if [ -z "$PART_LIST_DETAILED" ] 
then
# table is not using partitioning

# reset FROM counter to year 1970
FROM=0

# if table does not have partitions then optize whole table
date
echo "OPTIMIZE TABLE $OLD;"
mysql $DB -e "
SET SESSION SQL_LOG_BIN=0;
OPTIMIZE TABLE $OLD;
"
date

echo "do mysqldump of whole table $OLD"
mysqldump --set-gtid-purged=OFF --flush-logs --single-transaction --no-create-info \
$DB $OLD | gzip --fast > $DEST/$(date -d @$FROM "+%Y%m%d").$OLD.sql.gz
date

else
# if table contains partitions

# reset FROM counter to year 1970
FROM=0

# observe partition names and timestamps
echo "$PART_LIST_DETAILED" | \
grep -Eo "PARTITION.*VALUES LESS THAN..[0-9]+" | \
grep -v "^$" | \
while IFS= read -r LINE
do {

# name of partition
PARTITION=$(echo "$LINE" | grep -oP "PARTITION.\K\w+")

# rebuild partition, this will really free up free space if some records do not exist anymore
date
echo "ALTER TABLE $OLD REBUILD PARTITION $PARTITION;"
mysql $DB -e "
SET SESSION SQL_LOG_BIN=0;
ALTER TABLE $OLD REBUILD PARTITION $PARTITION;
"
date
# timestamp from, grab timstampe from previous partition
# this is greate workaround to NOT use 'select min(clock) from table partition x'
FROM=$TO
echo FROM=$FROM

# determine new timestamp
TO=$(echo "$LINE" | grep -Eo "[0-9]+$")
echo TO=$TO

# while the table is not locked by zabbix application do the backup
mysqldump \
--set-gtid-purged=OFF \
--flush-logs \
--single-transaction \
--no-create-info \
--where=" clock >= $FROM AND clock < $TO " \
$DB $OLD | gzip --fast > $DEST/$(date -d @$FROM "+%Y%m%d").$OLD.sql.gz

} done

fi

echo "RENAME TABLE $TABLE TO $TMP; RENAME TABLE $OLD TO $TABLE;"
mysql $DB -e "RENAME TABLE $TABLE TO $TMP; RENAME TABLE $OLD TO $TABLE;"

# move back data to table which has been colected
# during the time window when running this script
echo "SET SESSION SQL_LOG_BIN=0; INSERT IGNORE INTO $TABLE SELECT * FROM $TMP;"
mysql $DB -e "SET SESSION SQL_LOG_BIN=0; INSERT IGNORE INTO $TABLE SELECT * FROM $TMP;"

# drop temp table
echo "DROP TABLE $TMP;"
mysql $DB -e "DROP TABLE $TMP;"

echo

} done

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
echo "mysql $DB -e \"OPTIMIZE TABLE $table;\""
mysql $DB -e "SET SESSION SQL_LOG_BIN=0;OPTIMIZE TABLE $table;"
done

if [ -d "$DEST" ]; then
  find $DEST -type f -name '*.gz' -mtime +5 -exec rm {} \;
fi


/usr/sbin/zabbix_server -R housekeeper_execute

