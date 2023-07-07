#!/bin/bash

set -e
cd "$(dirname "$0")"

. ./defaults.env
. ./load_env.sh

if docker ps | grep -q bitcoind; then
    BITCOIND_CONTAINER_ID="$(docker ps | grep 'roygbiv-stack_bitcoind\.' | head -n1 | awk '{print $1;}')"

    if [ "$BTC_CHAIN" = mainnet ]; then
        docker exec -t -u 1000:1000 "$BITCOIND_CONTAINER_ID" bitcoin-cli "$@"
    else
        # for signet and regtest we have to pass the -CHAIN param
        docker exec -t -u 1000:1000 "$BITCOIND_CONTAINER_ID" bitcoin-cli -"$BTC_CHAIN" "$@"
    fi
else
    echo "ERROR: Cannot find the bitcoind container."
    exit 1
fi 
