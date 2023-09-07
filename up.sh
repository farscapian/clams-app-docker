#!/bin/bash

set -eu
cd "$(dirname "$0")"

# This script runs the whole Clams stack as determined by the various ./.env files

# check dependencies
for cmd in jq docker; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "This script requires \"${cmd}\" to be installed.."
        exit 1
    fi
done

# if we're running this locally, we will mount the plugin path into the containers
# this allows us to develop the prism-plugin.py and update it locally. Then the user
# can run ./reload_dev_plugins.sh and the plugins will be reregistered with every 
# cln node that's been deployed
DEV_PLUGIN_PATH="$(pwd)/lnplay/clightning/cln-plugins"

. ./defaults.env
. ./load_env.sh

if [ "$DO_NOT_DEPLOY" = true ]; then
    echo "INFO: The DO_NOT_DEPLOY was set to true in your environment file. You need to remove this before this script will execute."
    exit 1
fi

if [ "$CLN_COUNT" -gt 500 ]; then
    echo "ERROR: This software only supports up to 500 CLN nodes."
    exit 1
fi

RUN_CHANNELS=true
RETAIN_CACHE=false
USER_SAYS_YES=false

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --no-channels)
            RUN_CHANNELS=false
        ;;
        --retain-cache)
            RETAIN_CACHE=true
        ;;
        -y)
            USER_SAYS_YES=true
        ;;
        *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
done

if [ "$USER_SAYS_YES" = false ]; then
    ./prompt.sh
fi

# ensure we're using swarm mode.
if docker info | grep -q "Swarm: inactive"; then
    docker swarm init --default-addr-pool 10.10.0.0/16 --default-addr-pool-mask-length 22 > /dev/null
fi


if [ "$ENABLE_TLS" = true ] && [ "$DOMAIN_NAME" = localhost ]; then
    echo "ERROR: You can't use TLS with with a DOMAIN_NAME of 'localhost'. Use something that's resolveable by in DNS."
    exit 1
fi

if [ -n "$DOCKER_HOST" ]; then
    echo "INFO: All commands are being applied using the following DOCKER_HOST string: $DOCKER_HOST"
fi

echo "INFO: You are targeting '$BTC_CHAIN' using domain '$DOMAIN_NAME'."

if [ "$BTC_CHAIN" != regtest ] && [ "$BTC_CHAIN" != signet ] && [ "$BTC_CHAIN" != mainnet ]; then
    echo "ERROR: BTC_CHAIN must be either 'regtest', 'signet', or 'mainnet'."
    exit 1
fi

RPC_PATH="/root/.lightning/${BTC_CHAIN}/lightning-rpc"
if [ "$BTC_CHAIN" = mainnet ]; then
    RPC_PATH="/root/.lightning/bitcoin/lightning-rpc"
fi

export DOCKER_HOST="$DOCKER_HOST"
export CLIGHTNING_WEBSOCKET_EXTERNAL_PORT="$CLIGHTNING_WEBSOCKET_EXTERNAL_PORT"
export ENABLE_TLS="$ENABLE_TLS"
export BROWSER_APP_EXTERNAL_PORT="$BROWSER_APP_EXTERNAL_PORT"
export BROWSER_APP_GIT_REPO_URL="$BROWSER_APP_GIT_REPO_URL"

export CLN_COUNT="$CLN_COUNT"
export DEPLOY_CLAMS_BROWSER_APP="$DEPLOY_CLAMS_BROWSER_APP"
export DEPLOY_LNPLAYLIVE_FRONTEND="$DEPLOY_LNPLAYLIVE_FRONTEND"
export DEPLOY_PRISM_BROWSER_APP="$DEPLOY_PRISM_BROWSER_APP"
export DOMAIN_NAME="$DOMAIN_NAME"
export RPC_PATH="$RPC_PATH"
export STARTING_WEBSOCKET_PORT="$STARTING_WEBSOCKET_PORT"
export STARTING_CLN_PTP_PORT="$STARTING_CLN_PTP_PORT"
export CLN_P2P_PORT_OVERRIDE="$CLN_P2P_PORT_OVERRIDE"
export DEV_PLUGIN_PATH="$DEV_PLUGIN_PATH"
export LNPLAY_STACK_VERSION="$LNPLAY_STACK_VERSION"
export ENABLE_TOR="$ENABLE_TOR"
export REGTEST_BLOCK_TIME="$REGTEST_BLOCK_TIME"
export CHANNEL_SETUP="$CHANNEL_SETUP"
export ENABLE_CLN_DEBUGGING_OUTPUT="$ENABLE_CLN_DEBUGGING_OUTPUT"
export ENABLE_BITCOIND_DEBUGGING_OUTPUT="$ENABLE_BITCOIND_DEBUGGING_OUTPUT"

# lxd stuff
export LNPLAY_LXD_FQDN_PORT="$LNPLAY_LXD_FQDN_PORT"
export LNPLAY_LXD_PASSWORD="$LNPLAY_LXD_PASSWORD"


# plugins
export DEPLOY_PRISM_PLUGIN="$DEPLOY_PRISM_PLUGIN"
export DEPLOY_LNPLAYLIVE_PLUGIN="$DEPLOY_LNPLAYLIVE_PLUGIN"

mkdir -p "$LNPLAY_SERVER_PATH"

PRISM_APP_IMAGE_NAME="prism-browser-app:$LNPLAY_STACK_VERSION"
export PRISM_APP_IMAGE_NAME="$PRISM_APP_IMAGE_NAME"
ROOT_DIR="$(pwd)"
export ROOT_DIR="$ROOT_DIR"

if (( "$CLN_COUNT" < 5 )) && [ "$CHANNEL_SETUP" = prism ] && [ "$BTC_CHAIN" != mainnet ]; then
    echo "ERROR: You MUST have AT LEAST FIVE CLN nodes when deploying the prism channel setup."
    exit 1
fi

if ! docker stack list | grep -q lnplay; then
    RUN_CHANNELS=true

    # bring up the stack;
    ./lnplay/run.sh
fi

# now let's ensure all our containers are up.
function check_containers {

    # Check if bitcoind container is running
    if ! docker service list | grep lnplay_bitcoind | grep -q "1/1"; then
        return 1
    fi

    # Loop through all CLN nodes and check if they are running
    for (( CLN_ID=0; CLN_ID<CLN_COUNT; CLN_ID++ )); do
        if ! docker service list | grep "lnplay-cln-${CLN_ID}_cln-${CLN_ID}" | grep -q "1/1"; then
            return 1
        fi
    done

    # If all containers are running, return 0
    return 0
}

# Wait for all containers to be up and running
while ! check_containers; do
    sleep 3
    echo "INFO: Waiting for containers to come online..."
done


bcli() {
    "$ROOT_DIR/bitcoin-cli.sh" "$@"
}
export -f bcli

# wait for bitcoind to come oneline.


if [ "$BTC_CHAIN" != regtest ]; then
    # we need to do some kind of readiness check here.
    # in particular, check to ensure bitcoin-cli is returning json objects and IBD is complete.
    while true; do
        BLOCKCHAIN_INFO_JSON=$(bcli getblockchaininfo)

        ibd_status=$(echo "$BLOCKCHAIN_INFO_JSON" | jq -r '.initialblockdownload')
        verification_progress=$(echo "$BLOCKCHAIN_INFO_JSON" | jq -r '.verificationprogress')

        if [[ $ibd_status == "true" ]]; then
            echo "Initial Block Download is not complete. Current progress is $verification_progress"
        else
            echo "Initial Block Download has completed."
            break
        fi

        sleep 10  # Adjust the sleep duration as per your requirement
    done
fi

lncli() {
    "$ROOT_DIR/lightning-cli.sh" "$@"
}

export -f lncli

if [ "$RUN_CHANNELS" = true ]; then
    # ok, let's do the channel logic
    ./channel_templates/up.sh --retain-cache="$RETAIN_CACHE"
fi

./show_cln_uris.sh

if [ "$BTC_CHAIN" = regtest ]; then
    ./tests/run.sh 
fi
