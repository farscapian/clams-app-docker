#!/bin/bash

set -exu
cd "$(dirname "$0")"


for i in "$@"; do
    case $i in

        *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
done

# recache node addrs and pubkeys if not specified otherwise
echo "Caching node info..." >> /dev/null

rm -f "$LNPLAY_SERVER_PATH/node_addrs.txt"
rm -f "$LNPLAY_SERVER_PATH/node_pubkeys.txt"
rm -f "$LNPLAY_SERVER_PATH/any_offers.txt"

for ((NODE_ID=0; NODE_ID<CLN_COUNT; NODE_ID++)); do
    pubkey=$(../lightning-cli.sh --id=$NODE_ID getinfo | jq -r ".id")
    echo "$pubkey" >> "$LNPLAY_SERVER_PATH/node_pubkeys.txt"
done

echo "Node pubkeys cached" >> /dev/null

for ((NODE_ID=0; NODE_ID<CLN_COUNT; NODE_ID++)); do
    addr=$(../lightning-cli.sh --id=$NODE_ID newaddr | jq -r ".bech32")
    echo "$addr" >> "$LNPLAY_SERVER_PATH/node_addrs.txt"
done
echo "Node addresses cached" >> /dev/null

# if we're deploying prisms, then we also standard any offers on each node.
if [ "$CHANNEL_SETUP" = prism ] && [ "$BTC_CHAIN" != mainnet ]; then
    for ((NODE_ID=0; NODE_ID<CLN_COUNT; NODE_ID++)); do
        BOLT12_OFFER=$(../lightning-cli.sh --id=${NODE_ID} offer any default | jq -r '.bolt12')
        echo "$BOLT12_OFFER" >> "$LNPLAY_SERVER_PATH/any_offers.txt"
    done

    echo "BOLT12 any offers cached" >> /dev/null
fi


if [ "$BTC_CHAIN" != mainnet ]; then
    ./bitcoind_load_onchain.sh
fi

# With mainnet, all channel opens and spend must be done through a wallet app or the CLI
if [ "$BTC_CHAIN" = regtest ] || [ "$BTC_CHAIN" = signet ]; then
    ./cln_load_onchain.sh
fi

mapfile -t pubkeys < "$LNPLAY_SERVER_PATH/node_pubkeys.txt"

function connect_cln_nodes {
    echo "INFO: bootstrapping the P2P network." >> /dev/null

    # connect each node n to node [n+1]
    for ((NODE_ID=0; NODE_ID<CLN_COUNT; NODE_ID++)); do
        NEXT_NODE_ID=$((NODE_ID + 1))
        NODE_MOD_COUNT=$((NEXT_NODE_ID % CLN_COUNT))
        NEXT_NODE_PUBKEY=${pubkeys[$NODE_MOD_COUNT]}
        echo "Connecting 'cln-$NODE_ID' to 'cln-$NODE_MOD_COUNT' having pubkey '$NEXT_NODE_PUBKEY'." >> /dev/null
        ../lightning-cli.sh --id="$NODE_ID" connect "$NEXT_NODE_PUBKEY" "cln-$NODE_MOD_COUNT" 9735 >> /dev/null
    done
}

if [ "$BTC_CHAIN" = regtest ]; then

    if [ "$CLN_COUNT" -gt 1 ] && [ "$CONNECT_NODES" = true ]; then
        connect_cln_nodes
    fi

    # if we're doing a prism CHANNEL_SETUP, 
    # we bootstrap the nodes so they're well-connected,
    # then we open up the canonical channel setup.
    if [ "$CHANNEL_SETUP" = prism ]; then
        # now call the script that opens the channels.
        ./create_prism_channels.sh >> /dev/null
    fi

fi

# create a prism 
if [ "$CHANNEL_SETUP" = prism ] && [ "$DEPLOY_PRISM_PLUGIN" = true ]; then
    ./create_prism.sh
fi
