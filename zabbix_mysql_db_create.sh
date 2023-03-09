#!/bin/bash
 
versions="2.4
3.0
3.2
3.4
4.0
4.2
4.4
5.0
5.2"

 
# create use if it does not exist
# mysql -e 'DROP USER IF EXISTS "zabbix"@"127.0.0.1";'
# mysql -e 'CREATE USER "zabbix"@"127.0.0.1" IDENTIFIED BY "zabbix";'
# mysql -e 'ALTER USER "zabbix"@"127.0.0.1" IDENTIFIED WITH mysql_native_password BY "zabbix";'
# mysql -e 'FLUSH PRIVILEGES;'
 
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
 
# drop old database
mysql -e "DROP DATABASE IF EXISTS $db;"
 
# create blank database
mysql -e "CREATE DATABASE $db character set utf8 collate utf8_bin;"
 
# assign bare minimum permissions
mysql -e "GRANT SELECT, UPDATE, DELETE, INSERT, CREATE, DROP, ALTER, INDEX, REFERENCES ON $db.* TO \"zabbix\"@\"10.133.253.43\";"
 
# insert schema
cat database/mysql/schema.sql database/mysql/images.sql database/mysql/data.sql | mysql $db
 
} done

