#!/bin/bash

# zabbix server or zabbix proxy for zabbix sender
CONTACT=127.0.0.1
HOSTNAME=zbx.gnt1.el8uek

YEAR=$(date +%Y)
MONTH=$(date +%m)
DAY=$(date +%d)
CLOCK=$(date +%H%M)

VOLUME=/backup
MYSQLDIR=$VOLUME/mysql/zabbix/$YEAR/$MONTH/$DAY/$CLOCK
FILESYSTEM=$VOLUME/filesystem/$YEAR/$MONTH/$DAY/$CLOCK

DBNAME=zabbix

DR=/dr
rm -rf /dr

DEST="$DR"

mkdir -p "$DEST"

# seek for all servers which has a DR (disaster recovery tag)
# this block will create a blank restore.sh which will receive more content in upcomming steps
mysql \
--database=$DBNAME \
--silent \
--skip-column-names \
--batch \
--execute="
SELECT DISTINCT hosts.host
FROM items, hosts, items_applications, applications
WHERE items_applications.itemid=items.itemid
AND applications.applicationid=items_applications.applicationid
AND hosts.hostid=items.hostid
AND hosts.status=0
AND items.status=0
AND items.flags IN (0,4)
AND applications.name='DR'
" | \
while IFS= read -r HOSTNAME
do {
mkdir -p "$DEST/$HOSTNAME"
echo "#!/bin/bash" > "$DEST/$HOSTNAME/restore.sh"
echo >> "$DEST/$HOSTNAME/restore.sh"
} done


# unpack all itemids which holds disaster recovery data
mysql \
--database=$DBNAME \
--silent \
--skip-column-names \
--batch \
--execute="
SELECT items.itemid
FROM items, hosts, items_applications, applications
WHERE items_applications.itemid=items.itemid
AND applications.applicationid=items_applications.applicationid
AND hosts.hostid=items.hostid
AND hosts.status=0
AND items.status=0
AND items.flags IN (0,4)
AND applications.name='DR'
" | \
while IFS= read -r ITEMID
do {

HOSTNAME=$(mysql --database=$DBNAME --silent --skip-column-names --batch --execute="
SELECT hosts.host FROM hosts, items WHERE hosts.hostid=items.hostid AND items.itemid=$ITEMID
")

ITEMNAME=$(mysql --database=$DBNAME --silent --skip-column-names --batch --execute="SELECT name FROM items WHERE itemid=$ITEMID")


echo $HOSTNAME $ITEMID $ITEMNAME

echo "# $ITEMNAME" >> "$DEST/$HOSTNAME/restore.sh"
mysql \
--database=$DBNAME \
--silent \
--raw \
--skip-column-names \
--batch \
--execute="
SELECT value FROM history_text WHERE itemid=$ITEMID ORDER BY clock DESC LIMIT 1
" >> "$DEST/$HOSTNAME/restore.sh"
echo >> "$DEST/$HOSTNAME/restore.sh"

} done



if [ ! -d "$MYSQLDIR" ]; then
  mkdir -p "$MYSQLDIR"
fi

if [ ! -d "$FILESYSTEM" ]; then
  mkdir -p "$FILESYSTEM"
fi

# pack disaster recovery scripts
sudo tar -czvf $FILESYSTEM/dr.tar.gz /dr

echo -e "\nDelete itemid which do not exist anymore for an INTERNAL event"
mysql \
--database=$DBNAME \
--execute="
DELETE 
FROM events
WHERE events.source = 3 
AND events.object = 4 
AND events.objectid NOT IN (
SELECT itemid FROM items)
"

echo -e "\nDelete trigger event where triggerid do not exist anymore"
mysql \
--database=$DBNAME \
--execute="
DELETE
FROM events
WHERE source = 0
AND object = 0
AND objectid NOT IN
(SELECT triggerid FROM triggers)
"

echo -e "\nDelete history for items which either are history 0 or disabled or do not keep trends"
mysql \
--database=$DBNAME \
--execute="
DELETE FROM trends WHERE itemid IN (SELECT itemid FROM items WHERE value_type=0 AND trends='0' AND flags IN (0,4));
DELETE FROM trends WHERE itemid IN (SELECT itemid FROM items WHERE value_type=0 AND status=1 AND flags IN (0,4));
DELETE FROM trends_uint WHERE itemid IN (SELECT itemid FROM items WHERE value_type=3 AND trends='0' AND flags IN (0,4));
DELETE FROM trends_uint WHERE itemid IN (SELECT itemid FROM items WHERE value_type=3 AND status=1 AND flags IN (0,4));
DELETE FROM history_text WHERE itemid IN (SELECT itemid FROM items WHERE value_type=4 AND history='0' AND flags IN (0,4));
DELETE FROM history_text WHERE itemid IN (SELECT itemid FROM items WHERE value_type=4 AND status=1 AND flags IN (0,4));
DELETE FROM history_str WHERE itemid IN (SELECT itemid FROM items WHERE value_type=1 AND history='0' AND flags IN (0,4));
DELETE FROM history_str WHERE itemid IN (SELECT itemid FROM items WHERE value_type=1 AND status=1 AND flags IN (0,4));
DELETE FROM history_log WHERE itemid IN (SELECT itemid FROM items WHERE value_type=2 AND history='0' AND flags IN (0,4));
DELETE FROM history_log WHERE itemid IN (SELECT itemid FROM items WHERE value_type=2 AND status=1 AND flags IN (0,4));
"

# Discard unchanged 'history_text' for all item IDs
mysql \
--database=$DBNAME \
--silent \
--skip-column-names \
--batch \
--execute="
SELECT items.itemid
FROM items, hosts
WHERE hosts.hostid=items.hostid
AND hosts.status IN (0,1)
AND items.value_type=4
AND items.flags IN (0,4)
" | \
while IFS= read -r ITEMID
do {
echo $ITEMID
sleep 0.01
echo "
DELETE FROM history_text WHERE itemid=$ITEMID AND CLOCK IN (
SELECT CLOCK from (
SELECT CLOCK, value, r, v2 FROM (
SELECT CLOCK, value, LEAD(value,1) OVER (order by CLOCK) AS v2,
CASE
WHEN value <> LEAD(value,1) OVER (order by CLOCK)
THEN value
ELSE 'zero'
END AS r
FROM history_text WHERE itemid=$ITEMID
) x2
where r = 'zero'
) x3
WHERE v2 IS NOT NULL
)
" | mysql zabbix
} done


# Discard unchanged 'history_str' for all item IDs
mysql \
--database=$DBNAME \
--silent \
--skip-column-names \
--batch \
--execute="
SELECT items.itemid
FROM items, hosts
WHERE hosts.hostid=items.hostid
AND hosts.status IN (0,1)
AND items.value_type=1
AND items.flags IN (0,4)
" | \
while IFS= read -r ITEMID
do {
echo $ITEMID
sleep 0.01
echo "
DELETE FROM history_str WHERE itemid=$ITEMID AND CLOCK IN (
SELECT CLOCK from (
SELECT CLOCK, value, r, v2 FROM (
SELECT CLOCK, value, LEAD(value,1) OVER (order by CLOCK) AS v2,
CASE
WHEN value <> LEAD(value,1) OVER (order by CLOCK)
THEN value
ELSE 'zero'
END AS r
FROM history_str WHERE itemid=$ITEMID
) x2
where r = 'zero'
) x3
WHERE v2 IS NOT NULL
)
" | mysql --database=$DBNAME
} done


echo -e "\nExtracting schema"
/usr/bin/zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.status -o 1
mysqldump \
--set-gtid-purged=OFF \
--flush-logs \
--single-transaction \
--create-options \
--no-data \
--database=$DBNAME > "$MYSQLDIR/schema.sql" && \
xz "$MYSQLDIR/schema.sql"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
/usr/bin/zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.status -o 1
echo "mysqldump executed with error !!"
else
/usr/bin/zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.status -o 0
echo content of $MYSQLDIR
ls -lh $MYSQLDIR
fi

sleep 1

echo -e "\nBackup in one file. Useful to quickly bring back older configuration. while still keeping history"
echo "snapshot" && mysqldump \
--set-gtid-purged=OFF \
--flush-logs \
--single-transaction \
--ignore-table=$DBNAME.history \
--ignore-table=$DBNAME.history_log \
--ignore-table=$DBNAME.history_str \
--ignore-table=$DBNAME.history_text \
--ignore-table=$DBNAME.history_uint \
--ignore-table=$DBNAME.trends \
--ignore-table=$DBNAME.trends_uint \
--database=$DBNAME > "$MYSQLDIR/snapshot.sql" && \
echo "compressing snapshot" && \
xz "$MYSQLDIR/snapshot.sql"

# run backup on slave. if this server is not running virtual IP then backup
ip a | grep "192.168.88.55" || mysqldump --flush-logs \
--single-transaction \
--ignore-table=$DBNAME.history \
--ignore-table=$DBNAME.history_log \
--ignore-table=$DBNAME.history_str \
--ignore-table=$DBNAME.history_text \
--ignore-table=$DBNAME.history_uint \
--ignore-table=$DBNAME.trends \
--ignore-table=$DBNAME.trends_uint \
--database=$DBNAME | gzip > "$MYSQLDIR/snapshot.sql.gz"

sleep 1
echo -e "\nData backup including trends, str, log and text"
/usr/bin/zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.status -o 2
mysqldump \
--set-gtid-purged=OFF \
--flush-logs \
--single-transaction \
--no-create-info \
--ignore-table=$DBNAME.history \
--ignore-table=$DBNAME.history_uint \
--database=$DBNAME > "$MYSQLDIR/data.sql" && \
echo -e "\ncompressing data.sql with xz" && \
xz "$MYSQLDIR/data.sql"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
/usr/bin/zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.status -o 2
echo "mysqldump executed with error !!"
else
/usr/bin/zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.status -o 0
echo "content of $MYSQLDIR"
ls -lh "$MYSQLDIR"
fi

/usr/bin/zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.sql.data.size -o $(ls -s --block-size=1 $MYSQLDIR/data.sql.xz | grep -Eo "^[0-9]+")

sleep 1
echo -e "\nArchiving important directories and files"
/usr/bin/zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.status -o 3

sudo tar -czvf $FILESYSTEM/fs.conf.zabbix.tar.gz \
--files-from "/etc/zabbix/backup_zabbix_files.list" \
--files-from "/etc/zabbix/backup_zabbix_directories.list" \
/usr/bin/zabbix_* \
$(grep zabbix /etc/passwd|cut -d: -f6) \
/var/lib/grafana 

/usr/bin/zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.status -o $?

/usr/bin/zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.filesystem.size -o $(ls -s --block-size=1 $FILESYSTEM/fs.conf.zabbix.tar.xz | grep -Eo "^[0-9]+")

# remove older files than 30 DAYs
echo -e "\nThese files will be deleted:"
find /backup -type f -mtime +38
# delete files
find /backup -type f -mtime +38 -delete

echo -e "\nRemoving empty directories:"
find /backup -type d -empty -print
# delete empty directories
find /backup -type d -empty -print -delete

echo -e "\nUploading sql backup to google drive"
/usr/bin/zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.status -o 4
rclone -vv sync $VOLUME/mysql BackupMySQL:mysql

/usr/bin/zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.status -o $?

echo -e "\nUploading filesystem backup to google drive"
/usr/bin/zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.status -o 5
rclone -vv sync $VOLUME/filesystem BackupFileSystem:filesystem

/usr/bin/zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.status -o $?

# optimize tables
mysql \
--database=$DBNAME \
--silent \
--skip-column-names \
--batch \
--execute="
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA=\"$DBNAME\"
AND TABLE_NAME NOT IN ('history','history_uint')
ORDER BY DATA_FREE DESC;
" | \
while IFS= read -r TABLE_NAME
do {

echo "mysql $DBNAME -e \"OPTIMIZE TABLE $TABLE_NAME;\""

mysql \
--database=$DBNAME \
--silent \
--skip-column-names \
--batch \
--execute="
SET SESSION SQL_LOG_BIN=0;
OPTIMIZE TABLE $TABLE_NAME;
"

} done


