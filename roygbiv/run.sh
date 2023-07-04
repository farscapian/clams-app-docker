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

NGINX_CONFIG_PATH="$(pwd)/nginx.conf"
export NGINX_CONFIG_PATH="$NGINX_CONFIG_PATH"
CLN_IMAGE_NAME="roygbiv/cln:$ROYGBIV_STACK_VERSION"
export CLN_IMAGE_NAME="$CLN_IMAGE_NAME"

# TODO review base images; ensure get a secure/minial base image, e.g., https://hub.docker.com/r/blockstream/lightningd
BITCOIND_DOCKER_IMAGE_NAME="polarlightning/bitcoind:25.0"
export BITCOIND_DOCKER_IMAGE_NAME="$BITCOIND_DOCKER_IMAGE_NAME"
if ! docker image list | grep -q "$BITCOIND_DOCKER_IMAGE_NAME"; then
    # pull bitcoind down
    docker pull "$BITCOIND_DOCKER_IMAGE_NAME"
fi


TOR_PROXY_IMAGE_NAME="torproxy:$ROYGBIV_STACK_VERSION"
export TOR_PROXY_IMAGE_NAME="$TOR_PROXY_IMAGE_NAME"
if ! docker image inspect "$TOR_PROXY_IMAGE_NAME" &>/dev/null; then
    docker build -t "$TOR_PROXY_IMAGE_NAME" ./torproxy/
fi

LIGHTNINGD_DOCKER_IMAGE_NAME="polarlightning/clightning:23.05"
if ! docker image list | grep -q "$LIGHTNINGD_DOCKER_IMAGE_NAME"; then
    docker pull "$LIGHTNINGD_DOCKER_IMAGE_NAME"
fi

# Check if the image exists
if ! docker image inspect "$CLN_IMAGE_NAME" &>/dev/null; then
    # build the cln image with our plugins
    docker build -t "$CLN_IMAGE_NAME" --build-arg BASE_IMAGE="${LIGHTNINGD_DOCKER_IMAGE_NAME}" ./clightning/
fi


if [ "$DEPLOY_CLAMS_BROWSER_APP" = true ]; then
    # create a volume to hold the browser app build output
    if docker volume list | grep -q "clams-browser-app"; then
        docker volume rm clams-browser-app
        sleep 2
    fi


    docker volume create clams-browser-app

    if ! docker image inspect node:18 &> /dev/null; then
        # pull bitcoind down
        docker pull node:18
    fi

    BROWSER_APP_IMAGE_NAME="browser-app:$BROWSER_APP_GIT_TAG"

    if ! docker image inspect "$BROWSER_APP_IMAGE_NAME" &>/dev/null; then
        # build the browser-app image.
        # pull the base image from dockerhub and build the ./Dockerfile.
        if ! docker image list --format "{{.Repository}}:{{.Tag}}" | grep -q "$BROWSER_APP_IMAGE_NAME"; then
            docker build --build-arg GIT_REPO_URL="$BROWSER_APP_GIT_REPO_URL" \
            --build-arg VERSION="$ROYGBIV_STACK_VERSION" \
            -t "$BROWSER_APP_IMAGE_NAME" \
            ./browser-app/

            sleep 5
        fi
    fi

    docker run -it --rm -v clams-browser-app:/output --name browser-app "$BROWSER_APP_IMAGE_NAME"
fi

if ! docker image inspect "$PRISM_APP_IMAGE_NAME" &>/dev/null; then
    docker build --build-arg GIT_REPO_URL="$PRISM_APP_GIT_REPO_URL" \
    -t "$PRISM_APP_IMAGE_NAME" \
    ./prism-app/
fi

# for the nginx certificates.
docker volume create roygbiv-certs

# check to see if we have certificates
if [ "$ENABLE_TLS" = true ]; then
    ./getrenew_cert.sh
fi

DOCKER_COMPOSE_YML_PATH="$(pwd)/stacks/roygbiv-stack.yml"
export DOCKER_COMPOSE_YML_PATH="$DOCKER_COMPOSE_YML_PATH"
touch "$DOCKER_COMPOSE_YML_PATH"


# let's generate a random username and password and get our -rpcauth=<token>
BITCOIND_RPC_USERNAME=$(gpg --gen-random --armor 1 8 | tr -dc '[:alnum:]' | head -c10)
BITCOIND_RPC_PASSWORD=$(gpg --gen-random --armor 1 32 | tr -dc '[:alnum:]' | head -c32)
export BITCOIND_RPC_USERNAME="$BITCOIND_RPC_USERNAME"
export BITCOIND_RPC_PASSWORD="$BITCOIND_RPC_PASSWORD"




# stub out the docker-compose.yml file before we bring it up.
./stub_roygbiv-stack_compose.sh
./stub_nginx_conf.sh

# this is the main bitcoind/nginx etc., everything sans CLN nodes.
docker stack deploy -c "$DOCKER_COMPOSE_YML_PATH" roygbiv-stack

if ! docker network list | grep -q roygbiv-p2pnet; then
    docker network create roygbiv-p2pnet -d overlay
    sleep 1
fi

./stub_cln_composes.sh

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