#!/bin/bash

set -eu
cd "$(dirname "$0")"

# this script brings up the backend needed (i.e., lightningd+bitcoind) to test Clams app

WEBSOCKET_PORT_LOCAL=9736
CLIGHTNING_LOCAL_BIND_ADDR="127.0.0.1"
if [ "$ENABLE_TLS" = false ]; then
    WEBSOCKET_PORT_LOCAL="$CLIGHTNING_WEBSOCKET_EXTERNAL_PORT"
fi

export WEBSOCKET_PORT_LOCAL="$WEBSOCKET_PORT_LOCAL"
export CLIGHTNING_LOCAL_BIND_ADDR="$CLIGHTNING_LOCAL_BIND_ADDR"

NGINX_CONFIG_PATH="$LNPLAY_SERVER_PATH/nginx.conf"
export NGINX_CONFIG_PATH="$NGINX_CONFIG_PATH"

CLN_PYTHON_IMAGE_NAME="lnplay/cln-python:$LNPLAY_STACK_VERSION"
export CLN_PYTHON_IMAGE_NAME="$CLN_PYTHON_IMAGE_NAME"
CLN_IMAGE_NAME="lnplay/cln:$LNPLAY_STACK_VERSION"
export CLN_IMAGE_NAME="$CLN_IMAGE_NAME"

# TODO review base images; ensure get a secure/minial base image, e.g., https://hub.docker.com/r/blockstream/lightningd
BITCOIND_BASE_IMAGE_NAME="polarlightning/bitcoind:25.0"
BITCOIND_DOCKER_IMAGE_NAME="lnplay/bitcoind:$LNPLAY_STACK_VERSION"
export BITCOIND_DOCKER_IMAGE_NAME="$BITCOIND_DOCKER_IMAGE_NAME"

if ! docker image inspect "$BITCOIND_DOCKER_IMAGE_NAME" &>/dev/null; then
    # build custom bitcoind image
    docker build -q -t "$BITCOIND_DOCKER_IMAGE_NAME" --build-arg BASE_IMAGE="${BITCOIND_BASE_IMAGE_NAME}" ./bitcoind/  >>/dev/null
fi

BITCOIND_MANAGER_IMAGE_NAME="lnplay-manager:$LNPLAY_STACK_VERSION"
export BITCOIND_MANAGER_IMAGE_NAME="$BITCOIND_MANAGER_IMAGE_NAME"
if ! docker image inspect "$BITCOIND_MANAGER_IMAGE_NAME" &>/dev/null; then
    # pull bitcoind down
    docker build -q -t "$BITCOIND_MANAGER_IMAGE_NAME" --build-arg BASE_IMAGE="${BITCOIND_DOCKER_IMAGE_NAME}" ./manager/  >>/dev/null
fi

TOR_PROXY_IMAGE_NAME="torproxy:$LNPLAY_STACK_VERSION"
export TOR_PROXY_IMAGE_NAME="$TOR_PROXY_IMAGE_NAME"
if [ "$ENABLE_TOR" = true ]; then
    if ! docker image inspect "$TOR_PROXY_IMAGE_NAME" &>/dev/null; then
        docker build -q -t "$TOR_PROXY_IMAGE_NAME" ./torproxy/  >>/dev/null
    fi
fi

LIGHTNINGD_DOCKER_IMAGE_NAME="polarlightning/clightning:23.05.2"
REBUILD_CLN_IMAGE=false
if ! docker image inspect "$LIGHTNINGD_DOCKER_IMAGE_NAME" &>/dev/null; then
    docker pull -q "$LIGHTNINGD_DOCKER_IMAGE_NAME" >> /dev/null 
    REBUILD_CLN_IMAGE=true
fi

# build the base image for cln
if ! docker image inspect "$CLN_PYTHON_IMAGE_NAME" &>/dev/null; then
    # build the cln image with our plugins
    docker build -q -t "$CLN_PYTHON_IMAGE_NAME" --build-arg BASE_IMAGE="${LIGHTNINGD_DOCKER_IMAGE_NAME}" ./clightning/base/ >>/dev/null
fi

# build the base image for cln
if ! docker image inspect "$CLN_IMAGE_NAME" &>/dev/null || [ "$REBUILD_CLN_IMAGE" = true ]; then
    # build the cln image with our plugins
    # --build-arg CLN_VERSION="23.08"
    docker build -q -t "$CLN_IMAGE_NAME" --build-arg BASE_IMAGE="${CLN_PYTHON_IMAGE_NAME}" ./clightning/ >>/dev/null
fi

if [ "$DEPLOY_CLAMS_BROWSER_APP" = true ]; then
    CLAMS_APP_IMAGE_NAME="lnplay/clams:$LNPLAY_STACK_VERSION"
    CLAMS_APP_BASE_IMAGE_NAME="node:19.7"
    if ! docker image list --format "{{.Repository}}:{{.Tag}}" | grep -q "$CLAMS_APP_IMAGE_NAME"; then
        docker build -q -t "$CLAMS_APP_IMAGE_NAME"  --build-arg BASE_IMAGE="${CLAMS_APP_BASE_IMAGE_NAME}" ./clams/  >>/dev/null
        sleep 5
    fi
    
    export CLAMS_APP_IMAGE_NAME="$CLAMS_APP_IMAGE_NAME"
fi

if [ "$DEPLOY_PRISM_BROWSER_APP" = true ]; then
    if ! docker image inspect node:18 &> /dev/null; then
        # pull bitcoind down
        docker pull -q node:18 >> /dev/null
    fi

    if ! docker image inspect "$PRISM_APP_IMAGE_NAME" &>/dev/null; then
        docker build -q -t "$PRISM_APP_IMAGE_NAME" ./prism-app/  >>/dev/null
    fi
fi

if [ "$DEPLOY_LNPLAYLIVE_FRONTEND" = true ]; then
    if ! docker image inspect node:18 &> /dev/null; then
        # pull bitcoind down
        docker pull -q node:18 >> /dev/null
    fi

    if ! docker volume list | grep -q "lnplay-live"; then
        docker volume create lnplay-live
    fi
fi

NGINX_DOCKER_IMAGE_NAME="nginx:latest"
export NGINX_DOCKER_IMAGE_NAME="$NGINX_DOCKER_IMAGE_NAME"
if ! docker image inspect "$NGINX_DOCKER_IMAGE_NAME" &>/dev/null; then
    docker pull -q "$NGINX_DOCKER_IMAGE_NAME" >> /dev/null
fi

# check to see if we have certificates
if [ "$ENABLE_TLS" = true ]; then
    ./getrenew_cert.sh > /dev/null
fi

DOCKER_COMPOSE_YML_PATH="$LNPLAY_SERVER_PATH/lnplay.yml"
export DOCKER_COMPOSE_YML_PATH="$DOCKER_COMPOSE_YML_PATH"
touch "$DOCKER_COMPOSE_YML_PATH"


# let's generate a random username and password and get our -rpcauth=<token>
BITCOIND_RPC_USERNAME=$(gpg --gen-random --armor 1 8 | tr -dc '[:alnum:]' | head -c10)
BITCOIND_RPC_PASSWORD=$(gpg --gen-random --armor 1 32 | tr -dc '[:alnum:]' | head -c32)
export BITCOIND_RPC_USERNAME="$BITCOIND_RPC_USERNAME"
export BITCOIND_RPC_PASSWORD="$BITCOIND_RPC_PASSWORD"

# stub out the docker-compose.yml file before we bring it up.
./stub_lnplay_compose.sh
./stub_nginx_conf.sh

# this is the main bitcoind/nginx etc., everything sans CLN nodes.
docker stack deploy -c "$DOCKER_COMPOSE_YML_PATH" lnplay >> /dev/null

if ! docker network list | grep -q lnplay-p2pnet; then
    docker network create lnplay-p2pnet -d overlay >> /dev/null
    sleep 1
fi

./stub_cln_composes.sh

if [ "$BTC_CHAIN" = mainnet ]; then
    sleep 120
fi

# TODO poll for container existence.