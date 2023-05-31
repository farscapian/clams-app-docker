#!/bin/bash

set -e
cd "$(dirname "$0")"

# this script brings up the backend needed (i.e., lightningd+bitcoind) to test Clams app

# defaults are for regtest
BITCOIND_RPC_PORT=18443
if [ "$BTC_CHAIN" = testnet ]; then
    BITCOIND_RPC_PORT=18332
elif [ "$BTC_CHAIN" = signet ]; then
    BITCOIND_RPC_PORT=38332
elif [ "$BTC_CHAIN" = mainnet ]; then
    BITCOIND_RPC_PORT=8332

fi

export BITCOIND_RPC_PORT="$BITCOIND_RPC_PORT"
WEBSOCKET_PORT_LOCAL=9736
CLIGHTNING_LOCAL_BIND_ADDR="127.0.0.1"
if [ "$ENABLE_TLS" = false ]; then
    WEBSOCKET_PORT_LOCAL="$CLIGHTNING_WEBSOCKET_EXTERNAL_PORT"
fi

export WEBSOCKET_PORT_LOCAL="$WEBSOCKET_PORT_LOCAL"
export CLIGHTNING_LOCAL_BIND_ADDR="$CLIGHTNING_LOCAL_BIND_ADDR"

# we're using docker swarm style stacks, so enable swarm mode.
if docker info | grep -q "Swarm: inactive"; then
    docker swarm init
fi

NGINX_CONFIG_PATH="$(pwd)/nginx.conf"
export NGINX_CONFIG_PATH="$NGINX_CONFIG_PATH"

CLN_IMAGE_NAME="roygbiv/cln"
CLN_IMAGE_TAG="latest"
CLN_IMAGE="$CLN_IMAGE_NAME:$CLN_IMAGE_TAG"
export CLN_IMAGE="$CLN_IMAGE"

# TODO review base images; ensure get a secure/minial base image, e.g., https://hub.docker.com/r/blockstream/lightningd
BITCOIND_DOCKER_IMAGE_NAME="polarlightning/bitcoind:25.0"
export BITCOIND_DOCKER_IMAGE_NAME="$BITCOIND_DOCKER_IMAGE_NAME"
if ! docker image list | grep -q "$BITCOIND_DOCKER_IMAGE_NAME"; then
    # pull bitcoind down
    docker pull "$BITCOIND_DOCKER_IMAGE_NAME"
fi

LIGHTNINGD_DOCKER_IMAGE_NAME="polarlightning/clightning:23.02.2"
if ! docker image list | grep -q "$LIGHTNINGD_DOCKER_IMAGE_NAME"; then
    docker pull "$LIGHTNINGD_DOCKER_IMAGE_NAME"
fi


# stub out the docker-compose.yml file before we bring it up.
./stub_compose.sh
./stub_nginx_conf.sh

if [[ -z $(docker images -q torproxy:latest) ]]; then
    docker build -t torproxy:latest ./torproxy/
fi



# build the cln image with our plugins
docker build -t "$CLN_IMAGE_NAME:$CLN_IMAGE_TAG" ./clightning/

if [ "$DEPLOY_CLAMS_BROWSER_APP" = true ]; then
    # create a volume to hold the browser app build output
    if docker volume list | grep -q "clams-browser-app"; then
        docker volume rm clams-browser-app
        sleep 2
    fi


    docker volume create clams-browser-app

    BROWSER_APP_IMAGE_NAME="browser-app:$BROWSER_APP_GIT_TAG"

    # build the browser-app image.
    # pull the base image from dockerhub and build the ./Dockerfile.
    if ! docker image list --format "{{.Repository}}:{{.Tag}}" | grep -q "$BROWSER_APP_IMAGE_NAME"; then
        docker build --build-arg GIT_REPO_URL="$BROWSER_APP_GIT_REPO_URL" \
        --build-arg VERSION="$BROWSER_APP_GIT_TAG" \
        -t "$BROWSER_APP_IMAGE_NAME" \
        ./browser-app/

        sleep 5
    fi

    docker run -it --rm -v clams-browser-app:/output --name browser-app "$BROWSER_APP_IMAGE_NAME"
fi

docker build --build-arg GIT_REPO_URL="$PRISM_APP_GIT_REPO_URL" \
-t "$PRISM_APP_IMAGE_NAME" \
./prism-app/

sleep 5


docker build -t "torproxy:latest" ./torproxy/

sleep 5

# for the nginx certificates.
docker volume create roygbiv-certs

# check to see if we have certificates
if [ "$ENABLE_TLS" = true ]; then
    ./getrenew_cert.sh
fi

docker stack deploy -c docker-compose.yml roygbiv-stack


# the entrypoint is http in all cases; if ENABLE_TLS=true, then we rely on the 302 redirect to https.
echo "The prism-browser-app is available at http://${DOMAIN_NAME}:${BROWSER_APP_EXTERNAL_PORT}"

if [ "$DEPLOY_CLAMS_BROWSER_APP" = true ]; then
    echo "The clams-browser-app is available at http://${CLAMS_FQDN}:${BROWSER_APP_EXTERNAL_PORT}"
fi


if [ "$BTC_CHAIN" = mainnet ]; then
    sleep 120
else
    sleep 20
fi
# TODO poll for container existence.