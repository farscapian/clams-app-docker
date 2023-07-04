#!/bin/bash

set -e
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
DEV_PLUGIN_PATH="$(pwd)/roygbiv/clightning/cln-plugins/bolt12-prism"


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
RUN_TESTS=true
RETAIN_CACHE=false
USER_SAYS_YES=false

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --no-tests)
            RUN_TESTS=false
        ;;
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
export BROWSER_APP_GIT_TAG="$BROWSER_APP_GIT_TAG"
export CLN_COUNT="$CLN_COUNT"
export DEPLOY_CLAMS_BROWSER_APP="$DEPLOY_CLAMS_BROWSER_APP"
export DEPLOY_PRISM_BROWSER_APP="$DEPLOY_PRISM_BROWSER_APP"
export DOMAIN_NAME="$DOMAIN_NAME"
CLAMS_FQDN="clams.${DOMAIN_NAME}"
export CLAMS_FQDN="$CLAMS_FQDN"
export RPC_PATH="$RPC_PATH"
export STARTING_WEBSOCKET_PORT="$STARTING_WEBSOCKET_PORT"
export STARTING_CLN_PTP_PORT="$STARTING_CLN_PTP_PORT"
export CLN_P2P_PORT_OVERRIDE="$CLN_P2P_PORT_OVERRIDE"
export CLN0_ALIAS_OVERRIDE="$CLN0_ALIAS_OVERRIDE"
export PRISM_APP_GIT_REPO_URL="$PRISM_APP_GIT_REPO_URL"
export DEV_PLUGIN_PATH="$DEV_PLUGIN_PATH"
export ROYGBIV_STACK_VERSION="$ROYGBIV_STACK_VERSION"
export DISABLE_TOR="$DISABLE_TOR"

PRISM_APP_IMAGE_NAME="prism-browser-app:$ROYGBIV_STACK_VERSION"
export PRISM_APP_IMAGE_NAME="$PRISM_APP_IMAGE_NAME"
ROOT_DIR="$(pwd)"
export ROOT_DIR="$ROOT_DIR"

if ! docker stack list | grep -q roygbiv-stack; then
    RUN_CHANNELS=true

    # bring up the stack; or refresh it
    ./roygbiv/run.sh
fi


bcli() {
    "$ROOT_DIR/bitcoin-cli.sh" "$@"
}
export -f bcli


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

if [ -n "$DEV_PLUGIN_PATH" ] && [ "$BTC_CHAIN" = regtest ] && [ -d "$DEV_PLUGIN_PATH" ]; then
    ./reload_dev_plugins.sh
fi

if [ "$RUN_TESTS" = true ] && [ "$BTC_CHAIN" = regtest ]; then
    ./tests/run.sh 
fi
