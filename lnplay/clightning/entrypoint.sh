#!/bin/bash

set -eu

if [ "$SLEEP" = true ]; then
    sleep 500
fi


if [ -z "$CLN_ALIAS" ]; then
    echo "ERROR: CLN_ALIAS is unset."
    exit 1
fi

if [ -z "$BITCOIND_RPC_USERNAME" ]; then
    echo "ERROR: BITCOIND_RPC_USERNAME is unset."
    exit 1
fi

if [ -z "$BITCOIND_RPC_PASSWORD" ]; then
    echo "ERROR: BITCOIND_RPC_PASSWORD is unset."
    exit 1
fi

if [ -z "$CLN_NAME" ]; then
    echo "ERROR: CLN_NAME is unset."
    exit 1
fi

if [ -z "$ENABLE_TOR" ]; then
    echo "ERROR: ENABLE_TOR is unset."
    exit 1
fi

if [ -z "$DOMAIN_NAME" ]; then
    echo "ERROR: DOMAIN_NAME is unset."
    exit 1
fi

wait-for-it -t 60 "bitcoind:18443"



CLN_COMMAND="/usr/local/bin/lightningd --alias=${CLN_ALIAS} --bind-addr=0.0.0.0:9735 --log-file=debug.log --bitcoin-rpcuser=${BITCOIND_RPC_USERNAME} --bitcoin-rpcpassword=${BITCOIND_RPC_PASSWORD} --bitcoin-rpcconnect=bitcoind --bitcoin-rpcport=18443 --experimental-websocket-port=9736 --plugin=/opt/c-lightning-rest/plugin.js --experimental-offers --experimental-onion-messages --experimental-peer-storage"


if [ "$ENABLE_TOR" = true ]; then
    CLN_COMMAND="${CLN_COMMAND} --proxy=torproxy-${CLN_NAME}:9050"
fi

# if we're NOT in development mode, we go ahead and bake
#  the existing prism-plugin.py into the docker image.
# otherwise we will mount the path later down the road so
# plugins can be reloaded quickly without restarting the whole thing.
PLUGIN_PATH=/plugins
if [ "$DOMAIN_NAME" = "127.0.0.1" ]; then
    PLUGIN_PATH="/dev-plugins"
fi

if [ "$DEPLOY_PRISM_PLUGIN" = true ]; then
    PRISM_PLUGIN_PATH="$PLUGIN_PATH/bolt12-prism/prism-plugin.py"
    chmod +x "$PRISM_PLUGIN_PATH"
    CLN_COMMAND="$CLN_COMMAND --plugin=$PRISM_PLUGIN_PATH"
fi

if [ "$DEPLOY_LNPLAYLIVE_PLUGIN" = true ]; then
    LNPLAYLIVE_PLUGIN_PATH="$PLUGIN_PATH/lnplaylive/lnplay-live.py"
    chmod +x "$LNPLAYLIVE_PLUGIN_PATH"
    CLN_COMMAND="$CLN_COMMAND --plugin=$LNPLAYLIVE_PLUGIN_PATH"
fi

if [ "$ENABLE_CLN_DEBUGGING_OUTPUT" = true ]; then
    CLN_COMMAND="$CLN_COMMAND --log-level=debug"
fi

if [ -n "$BITCOIND_POLL_SETTING" ]; then
    CLN_COMMAND="$CLN_COMMAND --dev-bitcoind-poll=$BITCOIND_POLL_SETTING"
fi

# an admin can override the external port if necessary.
if [ "$BTC_CHAIN" = mainnet ] || [ "$BTC_CHAIN" = signet ]; then
    # set the announce-addr override
    if [ -n "$CLN_P2P_PORT_OVERRIDE" ]; then
        CLN_PTP_PORT="$CLN_P2P_PORT_OVERRIDE"
    fi

    CLN_COMMAND="$CLN_COMMAND --announce-addr=${DOMAIN_NAME}:${CLN_PTP_PORT} --announce-addr-dns=true"
fi

if [ "$BTC_CHAIN" = signet ]; then
    # signet only
    CLN_COMMAND="$CLN_COMMAND --network=${BTC_CHAIN}"
    CLN_COMMAND="$CLN_COMMAND --announce-addr=${DOMAIN_NAME}:${CLN_PTP_PORT} --announce-addr-dns=true"
fi

if [ "$BTC_CHAIN" = regtest ]; then
    # regtest only
    CLN_COMMAND="$CLN_COMMAND --network=${BTC_CHAIN}"
    CLN_COMMAND="$CLN_COMMAND --announce-addr=${CLN_NAME}:9735 --announce-addr-dns=true"
    CLN_COMMAND="$CLN_COMMAND --dev-fast-gossip"
    # CLN_COMMAND="$CLN_COMMAND --funder-policy=match"
    # CLN_COMMAND="$CLN_COMMAND --funder-policy-mod=100"
    # CLN_COMMAND="$CLN_COMMAND --funder-min-their-funding=10000"
    # CLN_COMMAND="$CLN_COMMAND --funder-per-channel-max=100000"
    # CLN_COMMAND="$CLN_COMMAND --funder-fuzz-percent=0"
    # CLN_COMMAND="$CLN_COMMAND --lease-fee-basis=50"
    # CLN_COMMAND="$CLN_COMMAND --lease-fee-base-sat=2sat"
    # CLN_COMMAND="$CLN_COMMAND --allow-deprecated-apis=false"
    CLN_COMMAND="$CLN_COMMAND --fee-base=1"
    CLN_COMMAND="$CLN_COMMAND --fee-per-satoshi=1"
fi


chown 1000:1000 /opt/c-lightning-rest/certs

exec $CLN_COMMAND