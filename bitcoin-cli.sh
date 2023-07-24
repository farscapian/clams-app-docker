#!/bin/bash

set -e
cd "$(dirname "$0")"

. ./defaults.env
. ./load_env.sh

BITCOIND_CONTAINER_ID="$(docker ps | grep 'roygbiv-stack_bitcoind.' | head -n1 | awk '{print $1;}')"
if [ -n "$BITCOIND_CONTAINER_ID" ]; then
    if [ "$BTC_CHAIN" = mainnet ]; then
        docker exec -t -u 1000:1000 "$BITCOIND_CONTAINER_ID" bitcoin-cli -rpcport=18443 "$@"
    else
        # for signet and regtest we have to pass the -CHAIN param
        docker exec -t -u 1000:1000 "$BITCOIND_CONTAINER_ID" bitcoin-cli -rpcport=18443 -"$BTC_CHAIN" "$@"
    fi
else
    echo "ERROR: Cannot find the bitcoind container."
    exit 1
fi 
