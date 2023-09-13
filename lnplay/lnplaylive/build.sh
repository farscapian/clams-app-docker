#!/bin/bash

set -exu
cd "$(dirname "$0")"

# before I can do any of this, I need to stub out the .env file...
# in order to do that, the lightning nodes need to be up first.
LNPLAY_LIVE_ENV="$(pwd)/app/.env"
PUBLIC_ADDRESS="$(bash -c "../../get_node_uri.sh --id=1 --port=6002")"
PUBLIC_WEBSOCKET_PROXY="$(echo "$PUBLIC_ADDRESS" | grep -o '@.*')"

WS_PROTO=ws
if [ "$ENABLE_TLS" = true ]; then
    WS_PROTO=wss
fi

PUBLIC_RUNE=$(bash -c "../../lightning-cli.sh --id=1 commando-rune restrictions='[[\"method^lnplaylive\",\"method=waitinvoice\",\"rate=120\"]]'"  | jq -r '.rune')

cat > "$LNPLAY_LIVE_ENV" <<EOF
PUBLIC_ADDRESS="${PUBLIC_ADDRESS}"
PUBLIC_RUNE="${PUBLIC_RUNE}"
PUBLIC_WEBSOCKET_PROXY="${WS_PROTO}://${PUBLIC_WEBSOCKET_PROXY:1}"
EOF

docker build -t "$LNPLAYLIVE_IMAGE_NAME" ./

# and then load them back up with our freshly build version.
docker run -t -v lnplay-live:/output "$LNPLAYLIVE_IMAGE_NAME" cp -r /app/build/ /output/