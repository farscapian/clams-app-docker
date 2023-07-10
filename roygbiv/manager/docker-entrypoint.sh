#!/bin/bash

set -eu

echo "INFO: starting bitcoind manager process"

if [ -z "$BLOCK_TIME" ]; then
    echo "ERROR: You MUST provide a block time. Set the BLOCK_TIME env var."
    exit 1
fi

if [ -z "$BITCOIND_SERVICE_NAME" ]; then
    echo "ERROR: You must specify the name of the bitcoind service."
    exit 1
fi

if [ -z "$BITCOIND_RPC_USERNAME" ]; then
    echo "ERROR: You must specify BITCOIND_RPC_USERNAME."
    exit 1
fi

if [ -z "$BITCOIND_RPC_PASSWORD" ]; then
    echo "ERROR: You must specify BITCOIND_RPC_PASSWORD."
    exit 1
fi

echo "BLOCK_TIME: $BLOCK_TIME"
echo "INFO: waiting for bitcoind RPC service to become available."
wait-for-it -t 300 "$BITCOIND_SERVICE_NAME":18443


bcli() {
    bitcoin-cli -regtest -rpcconnect="$BITCOIND_SERVICE_NAME" -rpcport=18443 -rpcuser="$BITCOIND_RPC_USERNAME" -rpcpassword="$BITCOIND_RPC_PASSWORD" "$@"
}
export -f bcli

createWallet() {
    # if the wallet doesn't exist, we create it.
    echo "INFO: running 'bcli createwallet $WALLET_NAME'."
    bcli createwallet "$WALLET_NAME" > /dev/null
    echo "INFO: Created '$WALLET_NAME' wallet."
}

# we assume the wallet doesn't exist.
WALLET_NAME=prism
if ! $(bcli listwalletdir | grep -q "$WALLET_NAME"); then
    # if the wallet doesn't exist, we create it.
    echo "INFO: listwalletdir suggests there is no wallet."
    createWallet
else
      # if the wallet walready exists, we load it.
    if ! bcli listwallets | grep -q "$WALLET_NAME"; then
        bcli loadwallet "$WALLET_NAME" > /dev/null
        echo "INFO: Loaded existing '$WALLET_NAME' wallet."
    fi
fi

# now that the wallet is opened, let's generate blocks every BLOCK_TIME
while (true); do

    bcli -generate

    # wait for the next block.
    sleep "$BLOCK_TIME"
done