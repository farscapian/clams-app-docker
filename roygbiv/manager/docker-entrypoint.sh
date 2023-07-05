#!/bin/bash

set -exu

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
echo "BITCOIND_SERVICE_NAME: $BITCOIND_SERVICE_NAME"
echo "BITCOIND_RPC_USERNAME: $BITCOIND_RPC_USERNAME"
echo "BITCOIND_RPC_PASSWORD: $BITCOIND_RPC_PASSWORD"

# the purpose of this script is to provide automated management of the bitcoind instance.
# in particular, this script will generate blocks every x seconds (configurable).
# if there are other things that needs to be done on an automated basis like this, we can
# put it here. But at the moment all I can think of is generating blocks.

while (true); do
    bitcoin-cli -regtest -rpcconnect="$BITCOIND_SERVICE_NAME" -rpcport=18443 -rpcuser="$BITCOIND_RPC_USERNAME" -rpcpassword="$BITCOIND_RPC_PASSWORD" -generate

    sleep "$BLOCK_TIME"
done