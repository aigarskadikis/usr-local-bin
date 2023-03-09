#!/bin/bash

# backup script based on SSH keys
# this will reach out a remote server and pool out an important configuration

DATE=/backup/filesystem/remote/$(date '+%Y%m%d%H%M')

DIRECTORY_LIST='
etc/zabbix
etc/sudoers.d
etc/cron.d
usr/lib/zabbix
var/lib/zabbix
etc/nginx/conf.d
etc/php-fpm.d
etc/opt/rh/rh-nginx116/nginx/conf.d
usr/local/bin
usr/share/zabbix/modules
etc/yum.repos.d
root/.ssh
etc/my.cnf.d
etc/sysctl.d
usr/share/zabbix-6.0.4/ui/modules
usr/share/zabbix-6.0.5/ui/modules
'

# define file list
FILE_LIST='
etc/hosts
etc/opt/rh/rh-php72/php-fpm.d/zabbix.conf
var/oled/postgresql/13/pgdata/postgresql.conf
var/oled/postgresql/14/pgdata/postgresql.conf
var/oled/postgresql/13/pgdata/pg_hba.conf
var/oled/postgresql/14/pgdata/pg_hba.conf
var/lib/pgsql/12/data/postgresql.conf
var/lib/pgsql/13/data/postgresql.conf
var/lib/pgsql/12/data/pg_hba.conf
var/lib/pgsql/13/data/pg_hba.conf
etc/resolv.conf
etc/corosync/corosync.conf
etc/selinux/config
etc/profile.d/postgres.sh
etc/systemd/system/zabbix-proxy.service.d/override.conf
etc/systemd/system/zabbix-server.service.d/override.conf
etc/systemd/system/zabbix-agent.service.d/override.conf
etc/systemd/system/zabbix-agent2.service.d/override.conf
etc/systemd/system/mysqld.service.d/override.conf
root/.my.cnf
root/.pgpass
etc/my.cnf
etc/default/isc-dhcp-server
etc/hostapd/hostapd.conf
etc/iptables.ipv4.nat
etc/iptables.ipv6.nat
etc/network/interfaces
boot/config.txt
boot/cmdline.txt
etc/systemd/system/hostapd.service.d/override.conf
etc/sysconfig/zabbix-agent
etc/sysconfig/zabbix-agent2
etc/sysconfig/zabbix-proxy
etc/sysconfig/zabbix-server
'

# server list of all nodes in cluster
SERVER_LIST='
ol8
riga
arm
broceni
au
'


# start server list loop
echo "$SERVER_LIST" | \
grep -v "^$" | \
while IFS= read -r SERVER
do {

echo "$SERVER" | grep "^au$" && USER=root || USER=root

# CHECK DIRECTORY LIST
echo "$DIRECTORY_LIST" | \
grep -v "^$" | \
while IFS= read -r DIR
do {

# check if dir exists on remote server
ssh $USER@$SERVER "ls /$(dirname "${DIR}")" < /dev/null

if [ $? -eq 0 ]; then

# print full file path
echo "$SERVER: /$DIR"

# create destination directory locally
mkdir -p "$DATE/$SERVER/$DIR"

# copy
scp -r $USER@$SERVER:/$DIR/* $DATE/$SERVER/$DIR

# directory exists
fi

} done
# end of direcotory list



# CHECK FILE LIST

echo "$FILE_LIST" | \
grep -v "^$" | \
while IFS= read -r FILE
do {

# check if dir exists on remote server
ssh $USER@$SERVER "ls /$(dirname "${FILE}")" < /dev/null

if [ $? -eq 0 ]; then

# check if file exists on remote server
ssh $USER@$SERVER "ls /$FILE" < /dev/null

# if file exists:
if [ $? -eq 0 ]; then

# print full file path
echo "$SERVER: /$FILE"

# create destination directory locally
mkdir -p "$DATE/$SERVER/${FILE%/*}"

# copy
scp -r $USER@$SERVER:/$FILE $DATE/$SERVER/$FILE

# file exists
fi

# directory exists
fi

} done
# end of file list

} done
# end of server list

tar cf - "$DATE" | xz -z - > "$DATE.tar.xz"
rm -rf "$DATE"

