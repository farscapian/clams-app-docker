#!/bin/bash

set -eu
cd "$(dirname "${BASH_SOURCE[0]}")"

DOCKER_HOST=

# Stub out active_env.txt if doesn't exist.
if [ ! -f ./active_env.txt ]; then
    # stub one out
    echo "local.env" >> ./active_env.txt
    echo "INFO: '$(pwd)/active_env.txt' was just stubbed out. You may need to update it. Right now you're targeting your local dockerd."
fi

ACTIVE_ENV=$(< "$(pwd)/active_env.txt" head -n1 | awk '{print $1;}')
export ACTIVE_ENV="$ACTIVE_ENV"

ENV_FILE="$(pwd)/environments/$ACTIVE_ENV"

if [ ! -f "$ENV_FILE" ]; then
    cat > "$ENV_FILE" << EOF
DOCKER_HOST=ssh://ubuntu@domain.tld
DOMAIN_NAME=domain.tld
ENABLE_TLS=true
EOF

    echo "WARNING: The env file '$ENV_FILE' didn't exist, so we stubbed it out. Go update it!"
    exit 1
fi

source "$ENV_FILE"

if [ "$DOMAIN_NAME" = "domain.tld" ]; then
    echo "ERROR: Hey, you didn't update your env file!"
    exit 1
fi

if [ "$DOMAIN_NAME" = "127.0.0.1" ] && [ "$ENABLE_TLS" = true ]; then
    echo "ERROR: Hey, you can't use TLS when your DOMAIN_NAME is equal to 127.0.0.1."
    exit 1
fi

if ! [[ $CLN_COUNT =~ ^[0-9]+$ ]]; then
    echo "ERROR: CLN_COUNT MUST be a number."
    exit 1
fi

export DOCKER_HOST="$DOCKER_HOST"
export DOMAIN_NAME="$DOMAIN_NAME"
export ENABLE_TLS="$ENABLE_TLS"
export BTC_CHAIN="$BTC_CHAIN"
export NAMES_FILE_PATH="$NAMES_FILE_PATH"
export LNPLAY_SERVER_PATH="$LNPLAY_SERVER_PATH"
export DIRECT_LINK_FRONTEND_URL_OVERRIDE_FQDN="$DIRECT_LINK_FRONTEND_URL_OVERRIDE_FQDN"
export ENABLE_CLAMS_V2_CONNECTION_STRINGS="$ENABLE_CLAMS_V2_CONNECTION_STRINGS"