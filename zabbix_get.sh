#!/bin/bash

DATA=system.uptime

printf -v LENGTH '%016x' "${#DATA}"

PACK=""

for (( i=14; i>=0; i-=2 )); do PACK="$PACK\\x${LENGTH:$i:2}"; done

resp=$(printf "ZBXD\1$PACK%s" "$DATA" | nc 127.0.0.1 10050 | tr '\0' '\n')

echo $resp
