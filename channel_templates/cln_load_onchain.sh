#!/bin/bash

# the purpose of this script is to ensure that all CLN nodes have on-chain funds.
# assumes bitcoind has a loaded wallet with spendable funds

set -eu

mapfile -t node_addrs < node_addrs.txt

SENDMANY_JSON="{"
SEND_AMT=1
NEED_TO_SEND=false

# fund each cln node
for ((CLN_ID=0; CLN_ID<CLN_COUNT; CLN_ID++)); do

    if [ "$CHANNEL_SETUP" = prism ]; then
        # cln nodes 2-4 DO NOT receive an on-chain balance.
        if (( CLN_ID >= 2 && CLN_ID <=4 )); then
            continue;
        fi
    fi

    OUTPUT_EXISTS=$(lncli --id="$CLN_ID" listfunds | jq '.outputs | length > 0')
    
    # if at least one output exists in the CLN node, then we know
    # the node has been funded previously, and we can therefore skip
    if [ "$OUTPUT_EXISTS" = true ]; then
        continue
    fi

    NEED_TO_SEND=true

    CLN_ADDR=${node_addrs[$CLN_ID]}

    # we don't fund nodes 2-n on the prism setup.
    if [ "$CHANNEL_SETUP" = prism ]; then
        if ((CLN_ID < 2 )); then
            SENDMANY_JSON="${SENDMANY_JSON}\"$CLN_ADDR\":$SEND_AMT,"
        fi
    fi

    # in CHANNEL_SETUP=none, everybody gets a bitcoin
    if [ "$CHANNEL_SETUP" = none ]; then
        SENDMANY_JSON="${SENDMANY_JSON}\"$CLN_ADDR\":$SEND_AMT,"
    fi
done

if [ "$NEED_TO_SEND" = true ]; then
    SENDMANY_JSON="${SENDMANY_JSON::-1}}"

    bcli sendmany "" "$SENDMANY_JSON" > /dev/null

    sleep "$REGTEST_BLOCK_TIME"
fi
