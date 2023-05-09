#!/bin/bash

set -e
cd "$(dirname "$0")"

. ./defaults.env
. ./load_env.sh

if docker ps | grep -q bitcoind; then
    BITCOIND_CONTAINER_ID="$(docker ps | grep bitcoind | head -n1 | awk '{print $1;}')"
    CMD="docker exec -t -u 1000:1000 $BITCOIND_CONTAINER_ID bitcoin-cli"
    if [ "$BTC_CHAIN" != mainnet ]; then
        CMD="$CMD -$BTC_CHAIN"
    fi
    
    CMD="$CMD $*"
    eval "$CMD"
else
    echo "ERROR: Cannot find the bitcoind container. Did you run it?"
    exit 1
fi 
