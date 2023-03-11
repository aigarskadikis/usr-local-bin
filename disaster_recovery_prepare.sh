#!/bin/bash

# this is script which will genarate another bash script which will allow to create new server from scratch

# time characteristics
YEAR=$(date +%Y)
MONTH=$(date +%m)
DAY=$(date +%d)
CLOCK=$(date +%H%M)

DATABASE=zabbix
DR=/dr
rm -rf /dr

DEST="$DR/$YEAR/$MONTH/$DAY"

mkdir -p "$DEST"

# seek for all servers which has a DR (disaster recovery tag)
# this block will create a blank restore.sh which will receive more content in upcomming steps
mysql \
--database=$DATABASE \
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
--database=$DATABASE \
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

HOSTNAME=$(mysql --database=$DATABASE --silent --skip-column-names --batch --execute="
SELECT hosts.host FROM hosts, items WHERE hosts.hostid=items.hostid AND items.itemid=$ITEMID
")

echo $HOSTNAME $ITEMID

mysql \
--database=$DATABASE \
--silent \
--raw \
--skip-column-names \
--batch \
--execute="
SELECT value FROM history_text WHERE itemid=$ITEMID ORDER BY clock DESC LIMIT 1
" >> "$DEST/$HOSTNAME/restore.sh"
echo >> "$DEST/$HOSTNAME/restore.sh"

} done

