#!/bin/bash
set -eu

COOKIE_FILE=/bitcoind-cookie/.cookie
COOKIE_FILE_CONTENT=$(cat "$COOKIE_FILE")
if [ ! -f "$COOKIE_FILE" ]; then
    echo "ERROR: Cannot find the authentication cookie."
    sleep 5
    exit 1
fi

BITCOIND_RPC_USERNAME=$(echo "$COOKIE_FILE_CONTENT" | cut -d':' -f1)
BITCOIND_RPC_PASSWORD=$(echo "$COOKIE_FILE_CONTENT" | cut -d':' -f2)
export BITCOIND_RPC_USERNAME="$BITCOIND_RPC_USERNAME"
export BITCOIND_RPC_PASSWORD="$BITCOIND_RPC_PASSWORD"

if [ "$BTC_CHAIN" != "mainnet" ]; then
    exec bitcoin-cli -rpcport=18443 -rpcuser="$BITCOIND_RPC_USERNAME" -rpcpassword="$BITCOIND_RPC_PASSWORD" -"${BTC_CHAIN}" "$@"
else
    exec bitcoin-cli -rpcport=18443 -rpcuser="$BITCOIND_RPC_USERNAME" -rpcpassword="$BITCOIND_RPC_PASSWORD" "$@"
fi