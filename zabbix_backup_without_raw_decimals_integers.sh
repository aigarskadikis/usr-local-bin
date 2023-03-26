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
OLDER=38

DBNAME=zabbix

DR=/dr
rm -rf /dr

DEST="$DR"

mkdir -p "$DEST"

# seek for all servers which has a DR (disaster recovery tag)
# this block will create a blank restore.sh which will receive more content in upcomming steps
zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o "prepare disaster recovery procedure"
mysql \
--silent \
--skip-column-names \
--batch \
$DBNAME --execute="
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
zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o $?

zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o "unpack all itemids which holds disaster recovery data"
mysql \
--silent \
--skip-column-names \
--batch \
$DBNAME --execute="
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
--silent \
--raw \
--skip-column-names \
--batch \
$DBNAME --execute="
SELECT value FROM history_text WHERE itemid=$ITEMID ORDER BY clock DESC LIMIT 1
" >> "$DEST/$HOSTNAME/restore.sh"
echo >> "$DEST/$HOSTNAME/restore.sh"

} done
zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o $?



if [ ! -d "$MYSQLDIR" ]; then
  mkdir -p "$MYSQLDIR"
fi

if [ ! -d "$FILESYSTEM" ]; then
  mkdir -p "$FILESYSTEM"
fi


zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o "pack disaster recovery scripts"
sudo tar -czvf $FILESYSTEM/dr.tar.gz /dr
zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o $?

zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o "Delete itemid which do not exist anymore for an INTERNAL event"
mysql $DBNAME --execute="
DELETE 
FROM events
WHERE events.source = 3 
AND events.object = 4 
AND events.objectid NOT IN (
SELECT itemid FROM items)
"
zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o $?

zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o "Delete trigger event where triggerid do not exist anymore"
mysql $DBNAME --execute="
DELETE
FROM events
WHERE source = 0
AND object = 0
AND objectid NOT IN
(SELECT triggerid FROM triggers)
"
zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o $?

zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o "Delete history for items which either are history 0 or disabled or do not keep trends"
mysql $DBNAME --execute="
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
zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o $?

zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o "Discard unchanged 'history_text' for all item IDs"
mysql \
--silent \
--skip-column-names \
--batch \
$DBNAME --execute="
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
zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o $?

zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o "Discard unchanged 'history_str' for all item IDs"
mysql \
--silent \
--skip-column-names \
--batch \
$DBNAME --execute="
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
" | mysql $DBNAME
} done
zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o $?

zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o "extract schema, all partitions"
mysqldump \
--set-gtid-purged=OFF \
--flush-logs \
--single-transaction \
--create-options \
--no-data $DBNAME > "$MYSQLDIR/schema.sql"
zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o $?

zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o "compress schema.sql with xz and default compression level"
xz "$MYSQLDIR/schema.sql"
zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o $?


zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o "downloading a plain snapshot. this may take a 500 MB or so"
mysqldump \
--set-gtid-purged=OFF \
--flush-logs \
--single-transaction \
--ignore-table=$DBNAME.history \
--ignore-table=$DBNAME.history_log \
--ignore-table=$DBNAME.history_str \
--ignore-table=$DBNAME.history_text \
--ignore-table=$DBNAME.history_uint \
--ignore-table=$DBNAME.trends \
--ignore-table=$DBNAME.trends_uint $DBNAME > "$MYSQLDIR/snapshot.sql"
zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o $?


zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o "compressing snapshot.sql with xz and default compression level"
xz "$MYSQLDIR/snapshot.sql"
zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o $?


zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o "data backup including trends, str, log and text. using lz4 compression on-the-fly"
mysqldump \
--set-gtid-purged=OFF \
--flush-logs \
--single-transaction \
--no-create-info \
--ignore-table=$DBNAME.history \
--ignore-table=$DBNAME.history_uint $DBNAME | lz4 > "$MYSQLDIR/data.sql.lz4" 
zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o ${PIPESTATUS[0]}

zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o "convert lz4 archive to xz"
unlz4 "$MYSQLDIR/data.sql.lz4" | xz > "$MYSQLDIR/data.sql.xz"
zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o $?


zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o "archiving important directories and files"
sudo tar -czvf $FILESYSTEM/fs.conf.zabbix.tar.gz \
--files-from "/etc/zabbix/backup_zabbix_files.list" \
--files-from "/etc/zabbix/backup_zabbix_directories.list" \
/usr/bin/zabbix_* \
$(grep zabbix /etc/passwd|cut -d: -f6)
zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o $?


# remove older files than 30 DAYs
echo -e "\nThese files will be deleted:"
find /backup -type f -mtime +$OLDER


zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o "remove older files than $OLDER DAYs"
find /backup -type f -mtime +$OLDER -delete
zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o $?


echo -e "\nRemoving empty directories:"
find /backup -type d -empty -print
# delete empty directories
find /backup -type d -empty -print -delete


zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o "uploading sql backup to google drive"
rclone -vv sync $VOLUME/mysql BackupMySQL:mysql
zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o $?


zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o "uploading filesystem backup to google drive"
rclone -vv sync $VOLUME/filesystem BackupFileSystem:filesystem
zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o $?


zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o "optimize all tables except those 7 tables"
mysql \
--silent \
--skip-column-names \
--batch \
$DBNAME --execute="
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA=\"$DBNAME\"
AND TABLE_NAME NOT IN ('history','history_uint','history_log','history_text','trends','trends_uint')
ORDER BY DATA_FREE DESC;
" | \
while IFS= read -r TABLE_NAME
do {

echo "mysql $DBNAME -e \"OPTIMIZE TABLE $TABLE_NAME;\""

mysql \
--silent \
--skip-column-names \
--batch \
$DBNAME --execute="
SET SESSION SQL_LOG_BIN=0;
OPTIMIZE TABLE $TABLE_NAME;
"

} done
zabbix_sender --zabbix-server $CONTACT --host $HOSTNAME -k backup.step -o $?


