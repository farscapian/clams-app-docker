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

if docker ps | grep -q "roygbiv-stack_cln-${NODE_ID}"; then
    CLN_CONTAINER_ID="$(docker ps | grep "roygbiv-stack_cln-${NODE_ID}" | head -n1 | awk '{print $1;}')"
    CMD="docker exec -t $CLN_CONTAINER_ID lightning-cli"
    if [ "$BTC_CHAIN" != mainnet ]; then
        CMD="$CMD --network $BTC_CHAIN"
    fi

    eval "$CMD $*"
else
    echo "ERROR: Cannot find the clightning container. Did you run it?"
    exit 1
fi
