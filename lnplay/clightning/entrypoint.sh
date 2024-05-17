#!/bin/bash

set -exu

# # add the deprovision script to the crontab to be executed every 10 minutes.
# echo "*/10 * * * * root $HOME/deprovision.sh >> /var/log/cron.log 2>&1" > /etc/cron.d/deprovision
# echo "" >> /etc/cron.d/deprovision
# touch /var/log/cron.log
# chmod 0644 /etc/cron.d/deprovision

# first start the cron daemon so the deprovision script will execute.
cron

if [ "$SLEEP" = true ]; then
    sleep 500
fi

if [ -z "$CLN_ALIAS" ]; then
    echo "ERROR: CLN_ALIAS is unset."
    exit 1
fi

if [ -z "$CLN_COLOR" ]; then
    echo "ERROR: CLN_COLOR is unset."
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

if [ -z "$BACKEND_FQDN" ]; then
    echo "ERROR: BACKEND_FQDN is unset."
    exit 1
fi

if [ -z "$PLUGIN_PATH" ]; then
    echo "ERROR: the CLN PLUGIN_PATH MUST be defined."
    exit 1
fi

wait-for-it -t 600 "bitcoind:18443"

CLN_COMMAND="/usr/local/bin/lightningd --alias=${CLN_ALIAS} --rgb=${CLN_COLOR} --bind-addr=0.0.0.0:9735 --bitcoin-rpcuser=${BITCOIND_RPC_USERNAME} --bitcoin-rpcpassword=${BITCOIND_RPC_PASSWORD} --bitcoin-rpcconnect=bitcoind --bitcoin-rpcport=18443 --bind-addr=ws::9736 --experimental-offers"


if [ "$ENABLE_TOR" = true ]; then
    CLN_COMMAND="${CLN_COMMAND} --proxy=torproxy-${CLN_NAME}:9050"
fi

if [ "$ENABLE_CLN_REST" = true ]; then
    CLN_COMMAND="${CLN_COMMAND} --clnrest-port=3010 --clnrest-protocol=http --clnrest-host=0.0.0.0"
fi

if [ "$DEPLOY_CLBOSS_PLUGIN" = true ]; then
    CLBOSS_PLUGIN_PATH="$PLUGIN_PATH/clboss/clboss"
    chmod +x "$CLBOSS_PLUGIN_PATH"
    CLN_COMMAND="$CLN_COMMAND --important-plugin=$CLBOSS_PLUGIN_PATH --clboss-auto-close=true --clboss-zerobasefee=allow"
fi

if [ "$DEPLOY_PRISM_PLUGIN" = true ]; then
    PRISM_PLUGIN_PATH="$PLUGIN_PATH/bolt12-prism/bolt12-prism.py"
    chmod +x "$PRISM_PLUGIN_PATH"
    CLN_COMMAND="$CLN_COMMAND --plugin=$PRISM_PLUGIN_PATH"
fi

if [ "$DEPLOY_RECKLESS_WRAPPER_PLUGIN" = true ]; then
    RECKLESS_WRAPPER_PLUGIN_PATH="$PLUGIN_PATH/cln-reckless-wrapper/cln-reckless-wrapper.py"
    chmod +x "$RECKLESS_WRAPPER_PLUGIN_PATH"
    CLN_COMMAND="$CLN_COMMAND --plugin=$RECKLESS_WRAPPER_PLUGIN_PATH"


    # let's also stub out the config file

    RECKLESS_CONFIG_PATH="/root/.lightning/reckless"
    mkdir -p "$RECKLESS_CONFIG_PATH"
    mkdir -p /root/.lightning/regtest
    cat <<EOF >> "/root/.lightning/regtest/config"
include /reckless-plugins/regtest-reckless.conf
EOF

fi

if [ "$DEPLOY_LNPLAYLIVE_PLUGIN" = true ]; then
    LNPLAYLIVE_PLUGIN_PATH="$PLUGIN_PATH/lnplaylive/lnplay-live-api.py"
    chmod +x "$LNPLAYLIVE_PLUGIN_PATH"
    CLN_COMMAND="$CLN_COMMAND --plugin=$LNPLAYLIVE_PLUGIN_PATH"

    LNPLAYLIVE_INVOICE_PAID_PLUGIN_PATH="$PLUGIN_PATH/lnplaylive/invoice_paid.py"
    chmod +x "$LNPLAYLIVE_INVOICE_PAID_PLUGIN_PATH"
    CLN_COMMAND="$CLN_COMMAND --plugin=$LNPLAYLIVE_INVOICE_PAID_PLUGIN_PATH"
fi

if [ "$BTC_CHAIN" = regtest ] && [ -n "$CLN_BITCOIND_POLL_SETTING" ]; then
    if [ "$CLN_BITCOIND_POLL_SETTING" = 0 ]; then
        CLN_BITCOIND_POLL_SETTING=1
    fi

    CLN_COMMAND="$CLN_COMMAND --dev-bitcoind-poll=$CLN_BITCOIND_POLL_SETTING"
fi

# an admin can override the external port if necessary.
if [ "$BTC_CHAIN" = mainnet ] || [ "$BTC_CHAIN" = signet ]; then
    # set the announce-addr override
    if [ -n "$CLN_P2P_PORT_OVERRIDE" ]; then
        CLN_PTP_PORT="$CLN_P2P_PORT_OVERRIDE"
    fi

    CLN_COMMAND="$CLN_COMMAND --announce-addr=${BACKEND_FQDN}:${CLN_PTP_PORT} --announce-addr-dns=true"
    # CLN_COMMAND="$CLN_COMMAND --disable-mpp"
    CLN_COMMAND="$CLN_COMMAND --experimental-dual-fund --experimental-splicing --experimental-peer-storage"
fi

if [ "$BTC_CHAIN" = signet ]; then
    # signet only
    CLN_COMMAND="$CLN_COMMAND --network=${BTC_CHAIN}"
fi

if [ "$BTC_CHAIN" = regtest ]; then
    # regtest only
    CLN_COMMAND="$CLN_COMMAND --network=${BTC_CHAIN}"
    CLN_COMMAND="$CLN_COMMAND --announce-addr=${CLN_NAME}:9735 --announce-addr-dns=true"
    CLN_COMMAND="$CLN_COMMAND --developer"
    CLN_COMMAND="$CLN_COMMAND --dev-fast-gossip"
    CLN_COMMAND="$CLN_COMMAND --experimental-dual-fund"
    CLN_COMMAND="$CLN_COMMAND --experimental-splicing"
    CLN_COMMAND="$CLN_COMMAND --experimental-peer-storage"
    CLN_COMMAND="$CLN_COMMAND --funder-policy=match"
    CLN_COMMAND="$CLN_COMMAND --funder-policy-mod=100"
    CLN_COMMAND="$CLN_COMMAND --lease-fee-base-sat=500sat"
    CLN_COMMAND="$CLN_COMMAND --lease-fee-basis=2"
    CLN_COMMAND="$CLN_COMMAND --channel-fee-max-base-msat=1sat"
    CLN_COMMAND="$CLN_COMMAND --channel-fee-max-proportional-thousandths=2"
    CLN_COMMAND="$CLN_COMMAND --funder-per-channel-max=5000000000"
    CLN_COMMAND="$CLN_COMMAND --funder-reserve-tank=400000000"
    CLN_COMMAND="$CLN_COMMAND --funder-policy-mod=105"
    CLN_COMMAND="$CLN_COMMAND --funder-fuzz-percent=3"
    CLN_COMMAND="$CLN_COMMAND --funder-per-channel-max=100000"
    CLN_COMMAND="$CLN_COMMAND --funder-min-their-funding=10000"
    CLN_COMMAND="$CLN_COMMAND --fee-per-satoshi=100"

    # TODO disable-ip-discovery

    # cln accepts only 1 block before the channel can be used.
    CLN_COMMAND="$CLN_COMMAND --funding-confirms=1"
    #CLN_COMMAND="$CLN_COMMAND --log-level=debug"
fi

# Specify the log file path
LOG_FILE="/root/.lightning/debug.log"

# we'll log all STDOUT/STDERR to debug.log
exec $CLN_COMMAND > >(tee -a "$LOG_FILE") 2>&1
