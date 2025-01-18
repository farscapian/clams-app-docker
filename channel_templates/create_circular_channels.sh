#!/bin/bash

set -eu

# the objective of this script is to create channels in the prism format.
# Alice -> Bob, then Bob creates a channels to all subsequent nodes.
# this allows creating Prisms with an arbitrary number of prism recipients.

mapfile -t pubkeys < "$LNPLAY_SERVER_PATH/node_pubkeys.txt"

function checkOutputs {
    # let's wait for an output to exist before we start creating any channels.
    OUTPUT_EXISTS=false
    while [ "$OUTPUT_EXISTS" = false ]; do
        # pool to ensure we have enough outputs to spend with.
        OUTPUT_EXISTS=$(../lightning-cli.sh --id="$1" listfunds | jq '.outputs | length > 0')

        # if at least one output exists in the CLN node, then we know
        # the node has been funded previously, and we can therefore skip
        if [ "$OUTPUT_EXISTS" = true ]; then
            echo "INFO: cln-$1 has sufficient funds." >> /dev/null
            break
        else
            sleep 3
        fi
    done
}
sleep 5


for ((NODE_ID=0; NODE_ID<CLN_COUNT; NODE_ID++)); do
    NEXT_NODE_ID=$((NODE_ID + 1))
    NODE_MOD_COUNT=$((NEXT_NODE_ID % CLN_COUNT))
    NEXT_NODE_PUBKEY=${pubkeys[$NODE_MOD_COUNT]}
    checkOutputs "$NODE_ID"
    ../lightning-cli.sh --id="$NODE_ID" fundchannel "$NEXT_NODE_PUBKEY" 10000000 >> /dev/null
done
