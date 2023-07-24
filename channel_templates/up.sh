#!/bin/bash

set -eu
cd "$(dirname "$0")"

function check_containers {
    # Check if bitcoind container is running
    if ! docker ps --filter "name=roygbiv-stack_bitcoind" --filter "status=running" | grep -q polarlightning/bitcoind; then
        return 1
    fi

    # Loop through all CLN nodes and check if they are running
    for (( CLN_ID=0; CLN_ID<CLN_COUNT; CLN_ID++ )); do
        if ! docker ps --filter "name=roygbiv-cln-${CLN_ID}_" --filter "status=running" | grep -q roygbiv/cln; then
            return 1
        fi
    done

    # If all containers are running, return 0
    return 0
}

# Wait for all containers to be up and running
while ! check_containers; do
    sleep 3
done

RETAIN_CACHE=false

for i in "$@"; do
    case $i in
        --retain-cache=*)
            RETAIN_CACHE="${i#*=}"
            shift
        ;;
        *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
done

# recache node addrs and pubkeys if not specified otherwise
if [ "$RETAIN_CACHE" = false ]; then
    echo "Caching node info..."

    rm -f ./node_addrs.txt
    rm -f ./node_pubkeys.txt
    rm -f ./any_offers.txt

    for ((NODE_ID=0; NODE_ID<CLN_COUNT; NODE_ID++)); do
        pubkey=$(lncli --id=$NODE_ID getinfo | jq -r ".id")
        echo "$pubkey" >> node_pubkeys.txt
    done

    echo "Node pubkeys cached"

    for ((NODE_ID=0; NODE_ID<CLN_COUNT; NODE_ID++)); do
        addr=$(lncli --id=$NODE_ID newaddr | jq -r ".bech32")
        echo "$addr" >> node_addrs.txt
    done
    echo "Node addresses cached"

    # if we're deploying prisms, then we also standard any offers on each node.
    if [ "$CHANNEL_SETUP" = prism ]; then
        for ((NODE_ID=0; NODE_ID<CLN_COUNT; NODE_ID++)); do
            BOLT12_OFFER=$(lncli --id=${NODE_ID} offer any default | jq -r '.bolt12')
            echo "$BOLT12_OFFER" >> any_offers.txt
        done

        echo "BOLT12 any offers cached"
    fi

fi

./bitcoind_load_onchain.sh

# With mainnet, all channel opens and spend must be done through a wallet app or the CLI
if [ "$BTC_CHAIN" = regtest ] || [ "$BTC_CHAIN" = signet ]; then
    ./cln_load_onchain.sh
fi

mapfile -t pubkeys < node_pubkeys.txt

function connect_cln_nodes {
    # iterate over each node and create one or more p2p connections.
    for ((NODE_ID=STARTING_ID; NODE_ID<P2PBOOTSTRAP_COUNT; NODE_ID++)); do

        # first we should check if the node has any peers already
        NODE_PEER_COUNT="$(lncli --id=${NODE_ID} listpeers | jq -r '.peers | length')"
        if [ "$NODE_PEER_COUNT" -gt "$NODE_CONNECTIONS_MAX" ]; then
            echo "Node $NODE_ID has $NODE_PEER_COUNT peers."
            continue
        fi

        for ((i=1; i <= $NODE_CONNECTIONS_MAX; i++)); do
            NEXT_NODE_ID=$((NODE_ID + i))
            NODE_MOD_COUNT=$((NEXT_NODE_ID % CLN_COUNT))
            NEXT_NODE_PUBKEY=${pubkeys[$NODE_MOD_COUNT]}

            lncli --id="$NODE_ID" connect "$NEXT_NODE_PUBKEY" "cln-$NODE_MOD_COUNT" 9735 > /dev/null

            echo "CLN-$NODE_ID connected to cln-$NODE_MOD_COUNT having pubkey $NEXT_NODE_PUBKEY."
        done
    done
}


if [ "$BTC_CHAIN" = regtest ]; then
    echo "INFO: Running the prism P2P network bootstrap."
    STARTING_ID=0
    P2PBOOTSTRAP_COUNT=$CLN_COUNT
    NODE_CONNECTIONS_MAX=3

    # connect each node to 3 adjacent nodes.
    connect_cln_nodes

    # if we're doing a prism CHANNEL_SETUP, 
    # we bootstrap the nodes so they're well-connected,
    # then we open up the canonical channel setup.
    if [ "$CHANNEL_SETUP" = prism ]; then
        # now call the script that opens the channels.
        ./create_prism_channels.sh
        #echo "skipping"
    fi

fi