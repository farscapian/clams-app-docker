#!/bin/bash

# the purpose of this script is to ensure that all CLN nodes have on-chain funds.
# assumes bitcoind has a loaded wallet with spendable funds

set -exu

mapfile -t node_addrs < "$LNPLAY_SERVER_PATH/node_addrs.txt"

SENDMANY_JSON="{"
SEND_AMT=1
NEED_TO_SEND=false

# fund each cln node
for ((CLN_ID=0; CLN_ID<CLN_COUNT; CLN_ID++)); do

    # if [ "$CHANNEL_SETUP" = prism ]; then
    #     # cln nodes 2-4 DO NOT receive an on-chain balance.
    #     if (( CLN_ID >= 2 && CLN_ID <=4 )); then
    #         continue;
    #     fi
    # fi

    OUTPUT_EXISTS=$(../lightning-cli.sh --id="$CLN_ID" listfunds | jq '.outputs | length > 0')
    
    # if at least one output exists in the CLN node, then we know
    # the node has been funded previously, and we can therefore skip
    if [ "$OUTPUT_EXISTS" = true ]; then
        continue
    fi

    NEED_TO_SEND=true

    CLN_ADDR=${node_addrs[$CLN_ID]}
    SENDMANY_JSON="${SENDMANY_JSON}\"$CLN_ADDR\":$SEND_AMT,"

done

if [ "$NEED_TO_SEND" = true ]; then
    SENDMANY_JSON="${SENDMANY_JSON::-1}}"

    ../bitcoin-cli.sh sendmany "" "$SENDMANY_JSON" >> /dev/null

    # let's quickly mine that transaction.
    ../bitcoin-cli.sh -generate 3 >> /dev/null

    # and we wait a bit longer so each cln will poll for the udpate.
    sleep "$REGTEST_BLOCK_TIME"
fi
