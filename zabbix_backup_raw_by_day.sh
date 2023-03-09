#!/bin/bash
SLEEP=1

# name of database
DB=zabbix

# total days to look forward to browse history
DAYS=2

# pointer of current date. a full yeasterday will be the first date
d=0

# will go through all days in past starting with yesterday
while((d < DAYS))
do {

# add +1
d=$((d+1))

# calculate time the backup should be made of
FROM=$(date -d "$((d+1)) DAY AGO" "+%Y-%m-%d")
TILL=$(date -d "$((d+0)) DAY AGO" "+%Y-%m-%d")

# tables to backup
echo "
history
history_uint
history_str
history_text
history_log
trends
trends_uint
" | \
grep -v "^$" | \
while IFS= read -r TABLE
do {

# check if this day is already in backup
# this is possible because each day is a separate file
if [ -f $FROM.$TILL.$TABLE.sql ]; then

# print if day is already in backup
echo "$FROM 00:00:00(inclusive) => $TILL 00:00:00(exclusive) $TABLE"

else

# perform backup operation
echo "$FROM 00:00:00(inclusive) => $TILL 00:00:00(exclusive) $TABLE"
mysqldump --flush-logs \
--single-transaction \
--no-create-info \
--where=" \
clock >= UNIX_TIMESTAMP(\"$(date -d "$((d+1)) DAY AGO" "+%Y-%m-%d 00:00:00")\") \
AND \
clock < UNIX_TIMESTAMP(\"$(date -d "$((d+0)) DAY AGO" "+%Y-%m-%d 00:00:00")\") \
" \
$DB $TABLE > current.sql && \
mv current.sql $FROM.$TILL.$TABLE.sql
# only if the mysqldump utility successfully finished operation
# only then the file will be renamed
# this allows to break and resume operation at any time

echo "sleeping for $SLEEP seconds"
sleep $SLEEP

# end of checking if corresponing date has been covered
fi

# end of table list to backup
} done

# end of going through dates
} done

