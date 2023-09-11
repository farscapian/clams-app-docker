#!/bin/bash

set -eu
cd "$(dirname "$0")"


# before I can do any of this, I need to stub out the .env file...
# in order to do that, the lightning nodes need to be up first.
LNPLAY_LIVE_ENV="$(pwd)/app/.env"

cat > "$LNPLAY_LIVE_ENV" <<EOF
PUBLIC_ADDRESS="CHANGE_THIS_VALUE"
PUBLIC_RUNE="CHANGE_THIS_VALUE"
PUBLIC_WEBSOCKET_PROXY="CHANGE_THIS_VALUE"
EOF

docker build -t "$LNPLAYLIVE_IMAGE_NAME" ./

docker run -t -v lnplaylive:/output "$LNPLAYLIVE_IMAGE_NAME" cp -r /app/build/ /output/