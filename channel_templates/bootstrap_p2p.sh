#!/bin/bash

set -e


mapfile -t pubkeys < node_pubkeys.txt


# iterate through each node and it open 4 P2P connections to its neigh neighbor.
for ((NODE_ID=0; NODE_ID<CLN_COUNT; NODE_ID++)); do

    # first we should check if the node has any peers already
    NODE_PEER_COUNT="$(lncli --id=${NODE_ID} listpeers | jq -r '.peers | length')"
    if (( "$NODE_PEER_COUNT" >= 4 )); then
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
