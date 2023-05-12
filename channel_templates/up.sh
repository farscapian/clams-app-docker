#!/bin/bash

set -e
cd "$(dirname "$0")"

# wait for bitcvoind container to startup
until docker ps | grep -q bitcoind; do
    sleep 0.1;
done;

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
if [ "$RETAIN_CACHE" == false ]; then
    echo "Caching node info..."

    rm -f ./node_addrs.txt
    rm -f ./node_pubkeys.txt

    for ((NODE_ID=0; NODE_ID<CLN_COUNT;NODE_ID++)); do
        pubkey=$(lncli --id=$NODE_ID getinfo | jq -r ".id")
        echo "$pubkey" >> node_pubkeys.txt
    done
    echo "Node pubkeys cached"

    for ((NODE_ID=0; NODE_ID<CLN_COUNT;NODE_ID++)); do
        addr=$(lncli --id=$NODE_ID newaddr | jq -r ".bech32")
        echo "$addr" >> node_addrs.txt
    done
        echo "Node addresses cached"

fi

MINIMUM_WALLET_BALANCE=5
if [ "$BTC_CHAIN" = signet ] || [ "$BTC_CHAIN" = mainnet ]; then
    MINIMUM_WALLET_BALANCE=0.004
fi

export MINIMUM_WALLET_BALANCE="$MINIMUM_WALLET_BALANCE"

# this is called for all btc_chains
./bitcoind_load_onchain.sh

# With mainnet, all channel opens and spend must be done through a wallet app or the CLI
if [ "$BTC_CHAIN" = regtest ] || [ "$BTC_CHAIN" = signet ]; then
    ./cln_load_onchain.sh
fi


if [ "$BTC_CHAIN" != mainnet ]; then
    ./bootstrap_p2p.sh
fi

# this represents the number of seconds per cln node we wait for service to come down
# TODO maybe poll for this? 
TIME_PER_CLN_NODE=3
sleep $((CLN_COUNT * TIME_PER_CLN_NODE))

# automatically open channels if on regtest or signet.
if [ "$BTC_CHAIN" = regtest ]; then

    ./cln_load_onchain.sh

    ./bootstrap_p2p.sh
    TIME_PER_CLN_NODE=3
    
    sleep $((CLN_COUNT * TIME_PER_CLN_NODE))

    ./regtest_prism.sh

fi