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


RUN_CHANNELS=false
RUN_TESTS=false
RETAIN_CACHE=false

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --no-channels)
            RUN_CHANNELS=false
            shift
        ;;
        --channels=*)
            RUN_CHANNELS="${i#*=}"
            shift
        ;;
        --run-tests)
            RUN_TESTS=true
        ;;
        --run-tests=*)
            RUN_TESTS="${i#*=}"
            shift
        ;;
        --retain-cache)
            RETAIN_CACHE=true
        ;;
        --retain-cache=*)
            RETAIN_CACHE="${i#*=}"
            shift
        ;;
        *)
        ;;
    esac
done

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


if [ "$CHANNELS_ONLY" = false ]; then
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

if [ "$WITH_TESTS" = true ]; then
    ./tests/run_cli_tests.sh
fi
if [ "$CHANNELS_ONLY" = false ]; then
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

if [ "$WITH_TESTS" = true ]; then
    ./tests/run_cli_tests.sh
fi

# the entrypoint is http in all cases; if ENABLE_TLS=true, then we rely on the 302 redirect to https.
echo "The prism-browser-app is available at http://${DOMAIN_NAME}:${BROWSER_APP_EXTERNAL_PORT}"

if [ "$DEPLOY_CLAMS_BROWSER_APP" = true ]; then
    echo "The clams-browser-app is available at http://${CLAMS_FQDN}:${BROWSER_APP_EXTERNAL_PORT}"
fi

# ok, let's do the channel logic
./channel_templates/up.sh --retain-cache="$RETAIN_CACHE"

if [ "$WITH_TESTS" == true ]; then
    ./tests/run.sh 
fi

./channel_templates/up.sh --retain-cache="$RETAIN_CACHE"

if [ "$WITH_TESTS" == true ]; then
    ./tests/run.sh 
fi