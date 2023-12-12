#!/bin/bash

set -exu
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
# this allows us to develop the prism.py and update it locally. Then the user
# can run ./reload_dev_plugins.sh and the plugins will be reregistered with every 
# cln node that's been deployed
DEV_PLUGIN_PATH="$(pwd)/lnplay/clightning/cln-plugins"

. ./defaults.env

RETAIN_CACHE=false
USER_SAYS_YES=false
RUN_SERVICES=true

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --retain-cache)
            RETAIN_CACHE=true
        ;;
        --no-services)
            RUN_SERVICES=false
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

. ./load_env.sh

if [ "$DO_NOT_DEPLOY" = true ]; then
    echo "INFO: The DO_NOT_DEPLOY was set to true in your environment file. You need to remove this before this script will execute."
    exit 1
fi

if [ "$CLN_COUNT" -gt "$MAX_SUPPORTED_NODES" ]; then
    # TODO. Only 150 nodes are supported, but this software has deployed over 600 nodes before. Just no support for it.
    # TODO. The way to scale this is out--that is, add more VMs and replicate bitcoind blocks. Each VM gets up to 150 nodes.
    # Having said all this, we can deploy many more, but the EBT will be longer.
    echo "ERROR: This software only supports up to '$MAX_SUPPORTED_NODES' (Dunbar's Number) of CLN nodes."
    exit 1
fi

if [ "$USER_SAYS_YES" = false ]; then
    ./prompt.sh
fi

UNIQUE_NAMES=$(wc -l < "$NAMES_FILE_PATH")
UNIQUE_NAMES=$((UNIQUE_NAMES+1))
# Check if line count is greater than the threshold
if [ "$UNIQUE_NAMES" -lt "$CLN_COUNT" ]; then
    echo "ERROR: Your names '$NAMES_FILE_PATH' MUST have at least $CLN_COUNT unique entries."
    exit 1
fi

# ensure we're using swarm mode.
if docker info | grep -q "Swarm: inactive"; then
    docker swarm init --default-addr-pool 10.10.0.0/16 --default-addr-pool-mask-length 21 >> /dev/null
fi


if [ "$ENABLE_TLS" = true ] && [ "$DOMAIN_NAME" = localhost ]; then
    echo "ERROR: You can't use TLS with with a DOMAIN_NAME of 'localhost'. Use something that's resolveable by in DNS."
    exit 1
fi


if [ "$BTC_CHAIN" != regtest ] && [ "$BTC_CHAIN" != signet ] && [ "$BTC_CHAIN" != mainnet ]; then
    echo "ERROR: BTC_CHAIN must be either 'regtest', 'signet', or 'mainnet'."
    exit 1
fi

RPC_PATH="/root/.lightning/${BTC_CHAIN}/lightning-rpc"
if [ "$BTC_CHAIN" = mainnet ]; then
    RPC_PATH="/root/.lightning/bitcoin/lightning-rpc"
fi

export CLIGHTNING_WEBSOCKET_EXTERNAL_PORT="$CLIGHTNING_WEBSOCKET_EXTERNAL_PORT"
export ENABLE_TLS="$ENABLE_TLS"
export BROWSER_APP_EXTERNAL_PORT="$BROWSER_APP_EXTERNAL_PORT"

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
export ENABLE_BITCOIND_DEBUGGING_OUTPUT="$ENABLE_BITCOIND_DEBUGGING_OUTPUT"
export BASIC_HTTP_AUTHENTICATION="$BASIC_HTTP_AUTHENTICATION"
export CONNECT_NODES="$CONNECT_NODES"
export RUN_SERVICES="$RUN_SERVICES"

LNPLAYLIVE_IMAGE_NAME="lnplay/lnplaylive:$LNPLAY_STACK_VERSION"
export LNPLAYLIVE_IMAGE_NAME="$LNPLAYLIVE_IMAGE_NAME"

# incus stuff
export LNPLAY_INCUS_FQDN_PORT="$LNPLAY_INCUS_FQDN_PORT"
export LNPLAY_INCUS_PASSWORD="$LNPLAY_INCUS_PASSWORD"
export LNPLAY_INCUS_HOSTMAPPINGS="$LNPLAY_INCUS_HOSTMAPPINGS"
export LNPLAY_CLUSTER_UNDERLAY_DOMAIN="$LNPLAY_CLUSTER_UNDERLAY_DOMAIN"
export LNPLAY_EXTERNAL_DNS_NAME="$LNPLAY_EXTERNAL_DNS_NAME"
export LNPLAY_ENV_FILE_PATH="$LNPLAY_ENV_FILE_PATH"
export LNPLAYLIVE_FRONTEND_ENV="$LNPLAYLIVE_FRONTEND_ENV"

# plugins
export DEPLOY_PRISM_PLUGIN="$DEPLOY_PRISM_PLUGIN"
export DEPLOY_LNPLAYLIVE_PLUGIN="$DEPLOY_LNPLAYLIVE_PLUGIN"
export DEPLOY_CLBOSS_PLUGIN="$DEPLOY_CLBOSS_PLUGIN"
export RENEW_CERTS="$RENEW_CERTS"

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
    # bring up the stack;
    ./lnplay/run.sh
fi

if [ "$RUN_SERVICES" = false ]; then
    exit 0
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
TRIES=0
while ! check_containers; do
    sleep 3
    echo "INFO: Waiting for containers to come online..." >> /dev/null
    TRIES=$((TRIES + 1))

    if [ "$TRIES" -gt 10 ]; then
        echo "ERROR: timed out waiting for containers to stop. Manual intervention required." >> /dev/null
        exit 1
    fi
done

# wait for bitcoind to come oneline.
if [ "$BTC_CHAIN" != regtest ]; then
    # we need to do some kind of readiness check here.
    # in particular, check to ensure bitcoin-cli is returning json objects and IBD is complete.
    while true; do
        BLOCKCHAIN_INFO_JSON=$(./bitcoin-cli.sh getblockchaininfo)

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

# if we are deploying the lnplaylive frontend, we can rebuild at this point
# because it required build-time info from the deployed backend. The build script below
# will stub out those envs and rebuild the output from the app.
if [ "$DEPLOY_LNPLAYLIVE_FRONTEND" = true ]; then
    env LNPLAYLIVE_FRONTEND_ENV="$LNPLAYLIVE_FRONTEND_ENV" ./lnplay/lnplaylive/build.sh
fi

if [[ "$CLN_COUNT" -gt 0 ]]; then
    # ok, let's do the channel logic
    bash -c "./channel_templates/up.sh --retain-cache=$RETAIN_CACHE"
fi

if [ -n "$CONNECTION_STRING_CSV_PATH" ] && [[ "$CLN_COUNT" -gt 0 ]]; then
    bash -c "./show_cln_uris.sh --output-file=$CONNECTION_STRING_CSV_PATH" >> /dev/null
fi