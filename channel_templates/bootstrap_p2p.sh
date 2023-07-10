#!/bin/bash

set -ex

mapfile -t pubkeys < node_pubkeys.txt

function bootstrap_p2p_partition {
    # iterate through each node and it open 4 P2P connections to its neigh neighbor.
    for ((NODE_ID=STARTING_ID; NODE_ID<P2PBOOSTRAP_COUNT; NODE_ID++)); do

        # first we should check if the node has any peers already
        NODE_PEER_COUNT="$(lncli --id=${NODE_ID} listpeers | jq -r '.peers | length')"
        if [ "$NODE_PEER_COUNT" -gt 4 ]; then
            echo "Node $NODE_ID has $NODE_PEER_COUNT peers."
            continue
        fi

        for i in {1..4}; do
            NODE_PLUS_I=$((NODE_ID+i))
            NODE_MOD_COUNT=$((NODE_PLUS_I%4))

            if [ "$NODE_MOD_COUNT" != "$NODE_ID" ]; then
                # Now open a p2p connection
                NEXT_NODE_PUBKEY=${pubkeys[$NODE_MOD_COUNT]}
                lncli --id="$NODE_ID" connect "$NEXT_NODE_PUBKEY" "cln-$NODE_MOD_COUNT" 9735 > /dev/null
                echo "CLN-$NODE_ID connected to $NEXT_NODE_PUBKEY"
            fi
        done

    done
}


STARTING_ID=0
P2PBOOSTRAP_COUNT=5

# create a partition for the prism demo
bootstrap_p2p_partition

# we create an entirely separate partition with the remaining nodes.
if (( CLN_COUNT > 5 )); then
    STARTING_ID=5
    ((P2PBOOSTRAP_COUNT = CLN_COUNT))
    echo "P2PBOOSTRAP_COUNT: $P2PBOOSTRAP_COUNT"
    bootstrap_p2p_partition
fi