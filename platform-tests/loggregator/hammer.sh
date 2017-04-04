#!/usr/bin/env sh
set -eu

cf restart https-drain

for i in `seq 1 $NUM_APPS`; do
    rm -f output-$i.txt
    cf restart logspinner-$i
    cf logs logspinner-$i > output-$i.txt 2>&1 &
done;

sleep 30 #wait 30 seconds for socket connection

for i in `seq 1 $NUM_APPS`; do
    curl -k "https://logspinner-$i.$CF_SYSTEM_DOMAIN?cycles=${CYCLES}&delay=${DELAY_US}us" &> /dev/null
done;

sleep 15

killall cf
