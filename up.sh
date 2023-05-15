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


RUN_CHANNELS=true
RUN_TESTS=true
RETAIN_CACHE=false
REFRESH_STACK=true

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
        *)
        ;;
    esac
done

if [ "$ACTIVE_ENV" != "local.env" ]; then
    read -p "WARNING: You are targeting something OTHER than a dev/local instance. Are you sure you want to continue? (yes/no): " answer

    # Convert the answer to lowercase
    ANSWER=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

    # Check if the answer is "yes"
    if [ "$ANSWER" != "yes" ]; then
        echo "Quitting."
        exit 1
    fi
fi

if [ "$ENABLE_TLS" = true ] && [ "$DOMAIN_NAME" = localhost ]; then
    echo "ERROR: You can't use TLS with with a DOMAIN_NAME of 'localhost'. Use something that's resolveable by in DNS."
    exit 1
fi

echo "INFO: All commands are being applied using the following DOCKER_HOST string: $DOCKER_HOST"
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

lncli() {
    "$ROOT_DIR/lightning-cli.sh" "$@"
}

bcli() {
    "$ROOT_DIR/bitcoin-cli.sh" "$@"
}

export -f lncli
export -f bcli

lncli() {
    "$ROOT_DIR/lightning-cli.sh" "$@"
}

bcli() {
    "$ROOT_DIR/bitcoin-cli.sh" "$@"
}

export -f lncli
export -f bcli


if [ "$RUN_CHANNELS" = true ]; then
    # ok, let's do the channel logic
    ./channel_templates/up.sh --retain-cache="$RETAIN_CACHE"
fi

if [ "$RUN_TESTS" == true ]; then
    ./tests/run.sh 
fi
