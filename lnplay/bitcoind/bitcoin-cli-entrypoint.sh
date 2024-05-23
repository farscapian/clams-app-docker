#!/bin/bash
set -eu

COOKIE_FILE_CONTENT=$(cat /bitcoind-cookie/.cookie)
BITCOIND_RPC_USERNAME=$(echo "$COOKIE_FILE_CONTENT" | cut -d':' -f1)
BITCOIND_RPC_PASSWORD=$(echo "$COOKIE_FILE_CONTENT" | cut -d':' -f2)
export BITCOIND_RPC_USERNAME="$BITCOIND_RPC_USERNAME"
export BITCOIND_RPC_PASSWORD="$BITCOIND_RPC_PASSWORD"

exec bitcoin-cli -rpcport=18443 -rpcuser="$BITCOIND_RPC_USERNAME" -rpcpassword="$BITCOIND_RPC_PASSWORD" -"${BTC_CHAIN}" "$@"
