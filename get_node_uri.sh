#!/bin/bash

set -e
cd "$(dirname "$0")"

. ./defaults.env
. ./load_env.sh

SHOW_INTERNAL=false
NODE_ID=0
PORT=9735

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --id=*)
            NODE_ID="${i#*=}"
            shift
        ;;
        --port=*)
            PORT="${i#*=}"
            shift
        ;;
        --internal-only)
            SHOW_INTERNAL=true
            shift
        ;;
        *)
        ;;
    esac
done

NODE_PUBKEY=$(bash -c "./lightning-cli.sh --id=$NODE_ID getinfo" | jq -r '.id')

if [ "$SHOW_INTERNAL" = true ]; then
    echo "$NODE_PUBKEY@cln-${NODE_ID}:$PORT"
else
    echo "$NODE_PUBKEY@$DOMAIN_NAME:$PORT"
fi