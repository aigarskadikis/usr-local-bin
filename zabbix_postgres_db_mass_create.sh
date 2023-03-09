#!/bin/bash

# this script woks without password inline because the global 'env' contains
# PGUSER=postgres
# PGPASSWORD=zabbix

# user 'zabbix' must already exist in postgresql engine
 
versions="2.4
3.0
3.2
3.4
4.0
4.2
4.4
5.0"

# check if global variables are installed
env | grep PGPASSWORD
if [ $? -eq 0 ]; then

 
if [ ! -d "~/zabbix-source" ]; then
git clone https://git.zabbix.com/scm/zbx/zabbix.git ~/zabbix-source
fi
 
cd ~/zabbix-source
 
echo "$versions" | while IFS= read -r ver
do {
echo $ver
 
db=z`echo $ver | sed "s|\.||"`
echo $db

git reset --hard HEAD && git clean -fd
git checkout release/$ver
./bootstrap.sh && ./configure && make dbschema

# drop existing database
dropdb --port=$1 $db
# in case of database do not exisist. it will produce errors

# create a new database and assign user. User must already exist
createdb --port=$1 --owner=zabbix $db 
 
# insert schema and data
cat database/postgresql/schema.sql database/postgresql/images.sql database/postgresql/data.sql | psql --port=$1 --user=zabbix $db
 
} done

else
echo please install global 'env' variables:
echo PGUSER=postgres
echo PGPASSWORD=zabbix

fi


