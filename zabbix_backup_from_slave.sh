#!/bin/bash

VIRTUAL_IP=192.168.88.55
CREDENTIALS=/root/.my.cnf

mkdir -p /root/zabbix.conf.backup

# run backup on slave. if this server is not running virtual IP then backup
ip a | grep "$VIRTUAL_IP" || \
mysqldump --defaults-file=$CREDENTIALS \
--flush-logs \
--single-transaction \
--ignore-table=zabbix.history \
--ignore-table=zabbix.history_log \
--ignore-table=zabbix.history_str \
--ignore-table=zabbix.history_text \
--ignore-table=zabbix.history_uint \
--ignore-table=zabbix.trends \
--ignore-table=zabbix.trends_uint \
zabbix | gzip > /root/zabbix.conf.backup/$(date +%Y%m%d.%H%M).quick.restore.sql.gz
# 'pcs resource disable zbx_srv_group' or 'systemctl stop zabbix-server'
# overwrite/restore older config. This config will not touch historial data
# zcat quick.restore.sql.gz | mysql zabbix
# 'pcs resource enable zbx_srv_group' or 'systemctl start zabbix-server'

echo -e "\nThese files will be deleted:"
find /root/zabbix.conf.backup -type f -mtime +30
# delete files
find /root/zabbix.conf.backup -type f -mtime +30 -delete

echo -e "\nRemoving empty directories:"
find /root/zabbix.conf.backup -type d -empty -print
# delete empty directories
find /root/zabbix.conf.backup -type d -empty -print -delete

