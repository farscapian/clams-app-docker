#!/bin/bash

set -eu
cd "$(dirname "$0")"

docker buildx install

if ! docker buildx ls | grep -q lnplay; then
    docker buildx create --name lnplay --use
fi

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

# this is our base image! for bitcoind/lightningd
LIGHTNINGD_DOCKER_BASE_IMAGE_NAME="czlw31/cln:v24.02.2"
export LIGHTNINGD_DOCKER_BASE_IMAGE_NAME="$LIGHTNINGD_DOCKER_BASE_IMAGE_NAME"
if ! docker image inspect "$LIGHTNINGD_DOCKER_BASE_IMAGE_NAME" &> /dev/null; then
    docker pull "$LIGHTNINGD_DOCKER_BASE_IMAGE_NAME"
fi

BITCOIND_DOCKER_IMAGE_NAME="lnplay/bitcoind:$LNPLAY_STACK_VERSION"
export BITCOIND_DOCKER_IMAGE_NAME="$BITCOIND_DOCKER_IMAGE_NAME"

if ! docker image inspect "$BITCOIND_DOCKER_IMAGE_NAME" &>/dev/null; then
    # build custom bitcoind image
    # the base lightning image should contain the correct bitcoind, so we 
    # just overwrite the entrypoint.
    docker buildx build -t "$BITCOIND_DOCKER_IMAGE_NAME" --build-arg BASE_IMAGE="$LIGHTNINGD_DOCKER_BASE_IMAGE_NAME" ./bitcoind/ --load
fi

BITCOIND_MANAGER_IMAGE_NAME="lnplay/manager:$LNPLAY_STACK_VERSION"
export BITCOIND_MANAGER_IMAGE_NAME="$BITCOIND_MANAGER_IMAGE_NAME"
if ! docker image inspect "$BITCOIND_MANAGER_IMAGE_NAME" &>/dev/null; then
    docker buildx build -t "$BITCOIND_MANAGER_IMAGE_NAME" --build-arg BASE_IMAGE="$LIGHTNINGD_DOCKER_BASE_IMAGE_NAME" ./manager/ --load
fi

TOR_PROXY_IMAGE_NAME="lnplay/torproxy:$LNPLAY_STACK_VERSION"
export TOR_PROXY_IMAGE_NAME="$TOR_PROXY_IMAGE_NAME"
if [ "$ENABLE_TOR" = true ]; then
    if ! docker image inspect "$TOR_PROXY_IMAGE_NAME" &>/dev/null; then
        docker buildx build -t "$TOR_PROXY_IMAGE_NAME" --build-arg BASE_IMAGE="$LIGHTNINGD_DOCKER_BASE_IMAGE_NAME"  ./torproxy/  --load
    fi
fi

# if the clboss binary doesn't exist, build it.
if [ ! -f ./clightning/cln-plugins/clboss/clboss ] && [ "$DEPLOY_CLBOSS_PLUGIN" = true ]; then
    CLBOSS_IMAGE_NAME="lnplay/clboss:$LNPLAY_STACK_VERSION"
    docker buildx build -t "$CLBOSS_IMAGE_NAME" -f ./clightning/cln-plugins/clboss/Dockerfile1 ./clightning/cln-plugins/clboss  --load
    docker run -t -v "$(pwd)/clightning/cln-plugins/clboss":/output "$CLBOSS_IMAGE_NAME" cp /usr/local/bin/clboss /output/clboss
fi

# build the base image for cln
CLN_PYTHON_IMAGE_NAME="lnplay/cln-python:$LNPLAY_STACK_VERSION"
export CLN_PYTHON_IMAGE_NAME="$CLN_PYTHON_IMAGE_NAME"
if ! docker image inspect "$CLN_PYTHON_IMAGE_NAME" &>/dev/null; then
    # build the cln image with our plugins
    docker buildx build -t "$CLN_PYTHON_IMAGE_NAME" --build-arg BASE_IMAGE="${LIGHTNINGD_DOCKER_BASE_IMAGE_NAME}" ./clightning/base/ --load
fi

# for some reason I can't get BUILDKIT=1 to work on this last step.
export DOCKER_BUILDKIT=0

# build the base image for cln
if ! docker image inspect "$CLN_IMAGE_NAME" &>/dev/null; then
    ./clightning/stub_cln_dockerfile.sh
    docker build -t "$CLN_IMAGE_NAME" ./clightning/
fi


export DOCKER_BUILDKIT=1

CLAMS_REMOTE_IMAGE_NAME="lnplay/clams:$LNPLAY_STACK_VERSION"
export CLAMS_REMOTE_IMAGE_NAME="$CLAMS_REMOTE_IMAGE_NAME"
if ! docker image inspect "$NODE_BASE_DOCKER_IMAGE_NAME" &>/dev/null; then
    docker pull -q "$NODE_BASE_DOCKER_IMAGE_NAME"
fi

if [ "$DEPLOY_CLAMS_REMOTE" = true ]; then
    if ! docker image inspect "$CLAMS_REMOTE_IMAGE_NAME" &>/dev/null; then
        docker buildx build  -t "$CLAMS_REMOTE_IMAGE_NAME" --build-arg BASE_IMAGE="${NODE_BASE_DOCKER_IMAGE_NAME}" ./clams/  --load
    fi
fi

NGINX_DOCKER_IMAGE_NAME="nginx:latest"
export NGINX_DOCKER_IMAGE_NAME="$NGINX_DOCKER_IMAGE_NAME"
if ! docker image inspect "$NGINX_DOCKER_IMAGE_NAME" &>/dev/null; then
    docker pull -q "$NGINX_DOCKER_IMAGE_NAME"
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

    # let's create an external volume for the bitcoind cookie so it can be made accessible
    # to both bitcoind (rw) and all the cln instance (ro)
    COOKIE_DOCKER_VOL="bitcoind-${BTC_CHAIN}-cookie"
    export COOKIE_DOCKER_VOL="$COOKIE_DOCKER_VOL"
    if ! docker volume list | grep $"$COOKIE_DOCKER_VOL"; then
        docker volume create "$COOKIE_DOCKER_VOL"
    fi

    # stub out the docker-compose.yml file before we bring it up.
    ./stub_lnplay_compose.sh

    ./stub_nginx_conf.sh

    # this is the main bitcoind/nginx etc., everything sans CLN nodes.
    # TODO AFTER we deploy this stack, we should issue a CURL command to the FRONTEND_FQDN
    # so that clams remote will preemptively serve Clams files. 

    # TODO to make Clams Remote faster, we should cache responses at the nginx.
    docker stack deploy -c "$DOCKER_COMPOSE_YML_PATH" lnplay 
    #--detach=false


    if ! docker network list | grep -q lnplay-p2pnet; then
        docker network create lnplay-p2pnet -d overlay
        sleep 1
    fi

    ./stub_cln_composes.sh

    if [ "$BTC_CHAIN" = mainnet ]; then
        sleep 25
    fi
fi