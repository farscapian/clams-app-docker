#!/bin/bash

set -e
cd "$(dirname "$0")"

. ./defaults.env

. ./load_env.sh

NODE_ID=0

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --id=*)
            NODE_ID="${i#*=}"
            shift
        ;;
        *)
        ;;
    esac
done

CLN_CONTAINER_ID="$(docker ps | grep "roygbiv-cln-${NODE_ID}_cln-${NODE_ID}" | head -n1 | awk '{print $1;}')"

if [ -z "$CLN_CONTAINER_ID" ]; then 
    echo "ERROR: Cannot find the clightning container. Did you run it?"
    exit 1
fi

if [ "$BTC_CHAIN" = mainnet ]; then
    docker exec -t "$CLN_CONTAINER_ID" lightning-cli "$@"
else
    docker exec -t "$CLN_CONTAINER_ID" lightning-cli --network "$BTC_CHAIN" "$@"
fi