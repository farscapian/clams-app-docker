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


# clear out the node addrs and pubkey cache
rm -f ./node_addrs.txt
rm -f ./node_pubkeys.txt

# cache node pubkeys
for ((NODE_ID=0; NODE_ID<CLN_COUNT;NODE_ID++)); do
    pubkey=$(lncli --id=$NODE_ID getinfo | jq -r ".id")
    echo "$pubkey" >> node_pubkeys.txt
done

# cache node addrs
for ((NODE_ID=0; NODE_ID<CLN_COUNT;NODE_ID++)); do
    addr=$(lncli --id=$NODE_ID newaddr | jq -r ".bech32")
    echo "$addr" >> node_addrs.txt
done

./bitcoind_load_onchain.sh

# now open channels depending on the setup.
if [ "$BTC_CHAIN" = regtest ]; then

    ./cln_load_onchain.sh

    ./bootstrap_p2p.sh

    ./regtest_prism.sh

fi