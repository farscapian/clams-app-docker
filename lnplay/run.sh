#!/bin/bash

set -eu
cd "$(dirname "$0")"

if [ "$BUILD_IMAGES" = true ]; then
    ./build_images.sh 
fi

# check to see if we have certificates
if { [[ "$ENABLE_TLS" = true ]] && [[ "$RENEW_CERTS" = true ]]; } || { ! docker volume list | grep -q lnplay-certs; }; then
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