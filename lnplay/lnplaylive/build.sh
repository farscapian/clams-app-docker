#!/bin/bash

set -eu
cd "$(dirname "$0")"


# this is the default case when a .env doesn't exist. We stub it out.
if [ "$CLN_COUNT" -gt 0 ] && [ -z "$LNPLAYLIVE_FRONTEND_ENV" ]; then
    # before I can do any of this, I need to stub out the .env file...
    # in order to do that, the lightning nodes need to be up first.
    LNPLAYLIVE_FRONTEND_ENV="$(pwd)/.env"
    PUBLIC_ADDRESS="$(bash -c "../../get_node_uri.sh --id=0 --port=$STARTING_WEBSOCKET_PORT")"
    PUBLIC_WEBSOCKET_PROXY="$(echo "$PUBLIC_ADDRESS" | grep -o '@.*')"

    WS_PROTO=ws
    if [ "$ENABLE_TLS" = true ]; then
        WS_PROTO=wss
    fi

    PUBLIC_RUNE=$(bash -c "../../lightning-cli.sh --id=0 commando-rune restrictions='[[\"method^lnplaylive\",\"method=waitinvoice\",\"rate=120\"]]'"  | jq -r '.rune')

    cat > "$LNPLAYLIVE_FRONTEND_ENV" <<EOF
PUBLIC_ADDRESS="${PUBLIC_ADDRESS}"
PUBLIC_RUNE="${PUBLIC_RUNE}"
PUBLIC_WEBSOCKET_PROXY="${WS_PROTO}://${PUBLIC_WEBSOCKET_PROXY:1}"
EOF

fi

if [ -f "$LNPLAYLIVE_FRONTEND_ENV" ]; then
    cp "$LNPLAYLIVE_FRONTEND_ENV" "$(pwd)/app/.env"

    docker build -q -t "$LNPLAYLIVE_IMAGE_NAME" --build-arg BASE_IMAGE="${NODE_BASE_DOCKER_IMAGE_NAME}" ./ >> /dev/null

    rm -rf ./app/node_modules
    rm -rf ./app/.sveltekit
    rm ./app/.env

    # and then load them back up with our freshly build version.
    docker run -t -v lnplay-live:/output "$LNPLAYLIVE_IMAGE_NAME" cp -r /lnplaylive/build/ /output/
else
    echo "ERROR: you are deploying the lnplaylive frontend application, but there is no .env file for it to build with! "
    echo "       you may need a backend deployment, or you need to define LNPLAYLIVE_FRONTEND_ENV in your config."
    exit 1
fi