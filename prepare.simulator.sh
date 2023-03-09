#!/bin/bash

SNMPWALK_DIR=/root/snmpwalk

rm -rf '/usr/share/snmpsim/data/public/1.3.6.1.6.1.1.0/*'

mkdir -p '/usr/share/snmpsim/data/public/1.3.6.1.6.1.1.0'

rm -rf '/tmp/phase*snmpwalk'

if [ -z "$1" ]; then

ls -1 "$SNMPWALK_DIR" | while IFS= read -r FILE
do {
echo "$FILE"

LAST_OCTET=$(echo "$FILE" | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | grep -Eo "[0-9]+$")

FUTURE_IP=$(echo "$LAST_OCTET" | sed 's|^|10.100.0.|')

echo "$FUTURE_IP"

# phase 1
grep "^\.[0-9]" "$SNMPWALK_DIR/$FILE" > /tmp/phase1.$FUTURE_IP.snmpwalk

# phase 2
sed "s|^.*NULL$||" /tmp/phase1.$FUTURE_IP.snmpwalk > /tmp/phase2.$FUTURE_IP.snmpwalk

# phase 3
grep -v " = STRING: [0-9a-f]\+:[0-9a-f][0-9a-f][0-9a-f][0-9a-f]" /tmp/phase2.$FUTURE_IP.snmpwalk > /tmp/phase3.$FUTURE_IP.snmpwalk

datafile.py --source-record-type=snmpwalk --input-file=/tmp/phase3.$FUTURE_IP.snmpwalk > /usr/share/snmpsim/data/public/1.3.6.1.6.1.1.0/$FUTURE_IP.snmprec

ifconfig lo:$LAST_OCTET $FUTURE_IP netmask 255.255.255.255

} done

fi

echo "put in network scan:"
ls -1 "$SNMPWALK_DIR" | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | grep -Eo "[0-9]+$" | sed 's|^|10.100.0.|' | tr '\n' ','


ls -1 "$SNMPWALK_DIR" | while IFS= read -r FILE
do {

LAST_OCTET=$(echo "$FILE" | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | grep -Eo "[0-9]+$")

FUTURE_IP=$(echo "$LAST_OCTET" | sed 's|^|10.100.0.|')

snmpwalk -v'2c' -c'public' $FUTURE_IP $1

} done

