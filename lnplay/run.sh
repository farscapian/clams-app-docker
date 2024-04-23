#!/bin/bash

set -exu
cd "$(dirname "$0")"

CLN_PYTHON_IMAGE_NAME="lnplay/cln-python:$LNPLAY_STACK_VERSION"
export CLN_PYTHON_IMAGE_NAME="$CLN_PYTHON_IMAGE_NAME"

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

CLN_IMAGE_NAME="lnplay/cln:$LNPLAY_STACK_VERSION"
export CLN_IMAGE_NAME="$CLN_IMAGE_NAME"

# TODO review base images; ensure get a secure/minial base image, e.g., https://hub.docker.com/r/blockstream/lightningd
BITCOIND_BASE_IMAGE_NAME="polarlightning/bitcoind:26.0"
BITCOIND_DOCKER_IMAGE_NAME="lnplay/bitcoind:$LNPLAY_STACK_VERSION"
export BITCOIND_DOCKER_IMAGE_NAME="$BITCOIND_DOCKER_IMAGE_NAME"

if ! docker image inspect "$BITCOIND_BASE_IMAGE_NAME" &> /dev/null; then
    docker pull -q "$BITCOIND_BASE_IMAGE_NAME"
fi

export DOCKER_BUILDKIT=0

if ! docker image inspect "$BITCOIND_DOCKER_IMAGE_NAME" &>/dev/null; then
    # build custom bitcoind image
    docker build -t "$BITCOIND_DOCKER_IMAGE_NAME" --build-arg BASE_IMAGE="$BITCOIND_BASE_IMAGE_NAME" ./bitcoind/
fi

BITCOIND_MANAGER_IMAGE_NAME="lnplay/manager:$LNPLAY_STACK_VERSION"
export BITCOIND_MANAGER_IMAGE_NAME="$BITCOIND_MANAGER_IMAGE_NAME"
if ! docker image inspect "$BITCOIND_MANAGER_IMAGE_NAME" &>/dev/null; then
    docker build -t "$BITCOIND_MANAGER_IMAGE_NAME" --build-arg BASE_IMAGE="$BITCOIND_DOCKER_IMAGE_NAME" ./manager/
fi

TOR_PROXY_IMAGE_NAME="torproxy:$LNPLAY_STACK_VERSION"
export TOR_PROXY_IMAGE_NAME="$TOR_PROXY_IMAGE_NAME"
if [ "$ENABLE_TOR" = true ]; then
    if ! docker image inspect "$TOR_PROXY_IMAGE_NAME" &>/dev/null; then
        docker build -t "$TOR_PROXY_IMAGE_NAME" ./torproxy/  >>/dev/null
    fi
fi

export DOCKER_BUILDKIT=1
#docker buildx install
#docker buildx create --name lnplay --use

LIGHTNINGD_DOCKER_IMAGE_NAME="elementsproject/lightningd:v24.02-amd64"
docker pull "$LIGHTNINGD_DOCKER_IMAGE_NAME"

if ! docker image inspect "$LIGHTNINGD_DOCKER_IMAGE_NAME" &>/dev/null; then
    docker buildx build --tag "$LIGHTNINGD_DOCKER_IMAGE_NAME" --platform=linux/amd64 --load ./lightning
fi

export DOCKER_BUILDKIT=0

# build the base image for cln
if ! docker image inspect "$CLN_PYTHON_IMAGE_NAME" &>/dev/null; then
    # build the cln image with our plugins
    docker build -t "$CLN_PYTHON_IMAGE_NAME" --build-arg BASE_IMAGE="${LIGHTNINGD_DOCKER_IMAGE_NAME}" ./clightning/base/
fi

OLD_DOCKER_HOST="$DOCKER_HOST"
DOCKER_HOST=
# if the clboss binary doesn't exist, build it.
if [ ! -f ./clightning/cln-plugins/clboss/clboss ] && [ "$DEPLOY_CLBOSS_PLUGIN" = true ]; then
    CLBOSS_IMAGE_NAME="lnplay/clboss:$LNPLAY_STACK_VERSION"
    docker build -t "$CLBOSS_IMAGE_NAME" -f ./clightning/cln-plugins/clboss/Dockerfile1 ./clightning/cln-plugins/clboss
    docker run -t -v "$(pwd)/clightning/cln-plugins/clboss":/output "$CLBOSS_IMAGE_NAME" cp /usr/local/bin/clboss /output/clboss
fi
DOCKER_HOST="$OLD_DOCKER_HOST"

# build the base image for cln
#if ! docker image inspect "$CLN_IMAGE_NAME" &>/dev/null || [ "$REBUILD_CLN_IMAGE" = true ]; then
    # build the cln image with our plugins
    # first we stub out the dockerfile.

    CLN_BUILD_PATH="$(pwd)/clightning"
    CLN_DOCKERFILE_PATH="$CLN_BUILD_PATH/Dockerfile"
    export CLN_DOCKERFILE_PATH="$CLN_DOCKERFILE_PATH"

    ./clightning/stub_cln_dockerfile.sh

    docker build -t "$CLN_IMAGE_NAME" --build-arg BASE_IMAGE="${CLN_PYTHON_IMAGE_NAME}" ./clightning/
#fi

CLAMS_REMOTE_IMAGE_NAME="lnplay/clams:$LNPLAY_STACK_VERSION"
if ! docker image inspect "$CLAMS_REMOTE_IMAGE_NAME" &>/dev/null; then
    docker pull -q "$NODE_BASE_DOCKER_IMAGE_NAME"
fi

if [ "$DEPLOY_CLAMS_REMOTE" = true ]; then
    docker build  -t "$CLAMS_REMOTE_IMAGE_NAME" --build-arg BASE_IMAGE="${NODE_BASE_DOCKER_IMAGE_NAME}" ./clams/ >> /dev/null
    export CLAMS_REMOTE_IMAGE_NAME="$CLAMS_REMOTE_IMAGE_NAME"
fi

NGINX_DOCKER_IMAGE_NAME="nginx:latest"
export NGINX_DOCKER_IMAGE_NAME="$NGINX_DOCKER_IMAGE_NAME"
if ! docker image inspect "$NGINX_DOCKER_IMAGE_NAME" &>/dev/null; then
    docker pull -q "$NGINX_DOCKER_IMAGE_NAME" >> /dev/null
fi


if [ "$RENEW_CERTS" = true ] && [ "$ENABLE_TLS" = true ]; then
    # check to see if we have certificates
    ./getrenew_cert.sh
fi

# the remainer of the script is ONLY if we intend to run the services.
# if we don't we are left with all the images ready to go.
# this is useful when you want to package up lnplay into a VM image (incus image)
# and distribute it or use it in production.
if [ "$RUN_SERVICES" = true ]; then
    DOCKER_COMPOSE_YML_PATH="$LNPLAY_SERVER_PATH/lnplay.yml"
    export DOCKER_COMPOSE_YML_PATH="$DOCKER_COMPOSE_YML_PATH"
    touch "$DOCKER_COMPOSE_YML_PATH"

    # let's generate a random username and password and get our -rpcauth=<token>
    # TODO see if I can get rid of all this and use bitcoind cookie auth instead.
    BITCOIND_RPC_USERNAME=$(gpg --gen-random --armor 1 8 | tr -dc '[:alnum:]' | head -c10)
    BITCOIND_RPC_PASSWORD=$(gpg --gen-random --armor 1 32 | tr -dc '[:alnum:]' | head -c32)
    export BITCOIND_RPC_USERNAME="$BITCOIND_RPC_USERNAME"
    export BITCOIND_RPC_PASSWORD="$BITCOIND_RPC_PASSWORD"

    # stub out the docker-compose.yml file before we bring it up.
    ./stub_lnplay_compose.sh
    ./stub_nginx_conf.sh

    # this is the main bitcoind/nginx etc., everything sans CLN nodes.
    # TODO AFTER we deploy this stack, we should issue a CURL command to the FRONTEND_FQDN
    # so that clams remote will preemptively serve Clams files. 

    # TODO to make Clams Remote faster, we should cache responses at the nginx.
    docker stack deploy -c "$DOCKER_COMPOSE_YML_PATH" lnplay

    if ! docker network list | grep -q lnplay-p2pnet; then
        docker network create lnplay-p2pnet -d overlay
        sleep 1
    fi

    ./stub_cln_composes.sh

    if [ "$BTC_CHAIN" = mainnet ]; then
        sleep 25
    fi
fi