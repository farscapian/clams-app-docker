#!/bin/bash

set -ex
cd "$(dirname "$0")"

# this script brings up the backend needed (i.e., lightningd+bitcoind) to test Clams app

IS_REGTEST=0
IS_TESTNET=0

CLIGHTNING_CHAIN="$BTC_CHAIN"

# defaults are for regtest
BITCOIND_RPC_PORT=18443

if [ "$BTC_CHAIN" = testnet ]; then
    IS_TESTNET=1
    BITCOIND_RPC_PORT=18332
elif [ "$BTC_CHAIN" = mainnet ]; then
    CLIGHTNING_CHAIN=bitcoin
    BITCOIND_RPC_PORT=8332
else
    IS_REGTEST=1
fi

export IS_REGTEST="$IS_REGTEST"
export IS_TESTNET="$IS_TESTNET"
export CLIGHTNING_CHAIN="$CLIGHTNING_CHAIN"
export BITCOIND_RPC_PORT="$BITCOIND_RPC_PORT"

WEBSOCKET_PORT_LOCAL=9736
CLIGHTNING_P2P_PORT=9735
CLIGHTNING_LOCAL_BIND_ADDR="127.0.0.1"
if [ "$ENABLE_TLS" = false ]; then
    WEBSOCKET_PORT_LOCAL="$CLIGHTNING_WEBSOCKET_EXTERNAL_PORT"
    CLIGHTNING_P2P_PORT="$CLIGHTNING_P2P_EXTERNAL_PORT"
fi

export CLIGHTNING_P2P_PORT="$CLIGHTNING_P2P_PORT"
export WEBSOCKET_PORT_LOCAL="$WEBSOCKET_PORT_LOCAL"
export CLIGHTNING_LOCAL_BIND_ADDR="$CLIGHTNING_LOCAL_BIND_ADDR"

# create docker volumes; regtest should never be persisted.
for CHAIN in signet testnet mainnet; do
    VOLUME_NAME="bitcoin-${CHAIN}"
    if ! docker volume list --format csv | grep -q "$VOLUME_NAME"; then
        docker volume create "$VOLUME_NAME"
    fi
done

# we're using docker swarm style stacks, so enable swarm mode.
if docker info | grep -q "Swarm: inactive"; then
    docker swarm init
fi

NGINX_CONFIG_PATH="$(pwd)/nginx.conf"
export NGINX_CONFIG_PATH="$NGINX_CONFIG_PATH"

CLN_IMAGE_NAME="roygbiv/cln"
CLN_IMAGE_TAG="23.02.2"
CLN_IMAGE="$CLN_IMAGE_NAME:$CLN_IMAGE_TAG"
export CLN_IMAGE="$CLN_IMAGE"


# stub out the docker-compose.yml file before we bring it up.
./stub_compose.sh
./stub_nginx_conf.sh

if ! docker image list | grep -q "roygbiv/clightning"; then

    docker pull "polarlightning/clightning:23.02.2"

    # build the docker image which contains dependencies for cln plugin prism.py

    docker build -t "$CLN_IMAGE_NAME:$CLN_IMAGE_TAG" .

    sleep 2

    echo "Your image '$CLN_IMAGE_NAME:$CLN_IMAGE_TAG' has been updated."
fi



docker stack deploy -c docker-compose.yml clams-stack

