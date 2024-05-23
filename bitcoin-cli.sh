#!/bin/bash

set -eu
cd "$(dirname "$0")"

. ./defaults.env
. ./load_env.sh

BITCOIND_CONTAINER_ID="$(docker ps | grep 'lnplay_bitcoind.' | head -n1 | awk '{print $1;}')"
if [ -n "$BITCOIND_CONTAINER_ID" ]; then
    docker exec -t "$BITCOIND_CONTAINER_ID" /bitcoin-cli "$@"
else
    echo "ERROR: Cannot find the bitcoind container."
    exit 1
fi 
