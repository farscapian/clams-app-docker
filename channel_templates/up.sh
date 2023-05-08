#!/bin/bash

set -e
cd "$(dirname "$0")"

# wait for bitcvoind container to startup
until docker ps | grep -q bitcoind; do
    sleep 0.1;
done;

# set these funcs and vars here for testing
lncli() {
    "./../lightning-cli.sh" "$@"
}

bcli() {
    "./../bitcoin-cli.sh" "$@"
}

export -f lncli
export -f bcli

# clear out the node list and pubkey list
rm node_pubkeys.txt
rm node_addrs.txt

#lets get the node pubkeys one time and write them to a text file
if [ ! -f node_pubkeys.txt ]; then
    for ((NODE_ID=0; NODE_ID<CLN_COUNT;NODE_ID++)); do
        pubkey=$(lncli --id=$NODE_ID getinfo | jq -r ".id")
        echo "$pubkey" >> node_pubkeys.txt
    done
fi

if [ ! -f node_addrs.txt ]; then
    for ((NODE_ID=0; NODE_ID<CLN_COUNT;NODE_ID++)); do
        addr=$(lncli --id=$NODE_ID newaddr | jq -r ".bech32")
        echo "$addr" >> node_addrs.txt
    done
fi

./bitcoind_load_onchain.sh

./cln_load_onchain.sh

./bootstrap_p2p.sh

# now open channels depending on the setup.
if [ "$BTC_CHAIN" = regtest ]; then
    ./regtest_prism.sh
fi