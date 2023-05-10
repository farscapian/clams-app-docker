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

./bitcoind_load_onchain.sh

# now open channels depending on the setup.
if [ "$BTC_CHAIN" = regtest ]; then

    ./cln_load_onchain.sh

    ./bootstrap_p2p.sh
    TIME_PER_CLN_NODE=3
    
    sleep $((CLN_COUNT * TIME_PER_CLN_NODE))

    ./regtest_prism.sh

fi