#!/bin/bash

set -e
cd "$(dirname "$0")"

# This script runs the whole Clams stack as determined by the various ./.env files

# check dependencies
for cmd in jq docker dig; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "This script requires \"${cmd}\" to be installed.."
        exit 1
    fi
done

. ./defaults.env
. ./load_env.sh

if [ "$CLN_COUNT" -gt 15 ]; then
    echo "ERROR: This software only supports up to 15 CLN nodes."
    exit 1
fi


RUN_CHANNELS=true
RUN_TESTS=true
RETAIN_CACHE=false
REFRESH_STACK=true
USER_SAYS_YES=false

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --run-channels)
            RUN_CHANNELS=true
            shift
        ;;
        --no-stack-refresh)
            REFRESH_STACK=false
            shift
        ;;
        --run-tests)
            RUN_TESTS=true
        ;;
        --retain-cache)
            RETAIN_CACHE=true
        ;;
        -y)
            USER_SAYS_YES=true
        ;;
        *)
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
export PRISM_APP_GIT_REPO_URL="$PRISM_APP_GIT_REPO_URL"

PRISM_APP_IMAGE_NAME="prism-browser-app:main"
export PRISM_APP_IMAGE_NAME="$PRISM_APP_IMAGE_NAME"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR="$ROOT_DIR"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR="$ROOT_DIR"

if [ "$REFRESH_STACK" = true ]; then
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


if [ "$RUN_CHANNELS" = true ] && [ "$BTC_CHAIN" != mainnet ]; then
    # ok, let's do the channel logic
    ./channel_templates/up.sh --retain-cache="$RETAIN_CACHE"
fi

if [ "$RUN_TESTS" = true ]; then
    ./tests/run.sh 
fi
