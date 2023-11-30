#!/bin/bash

set -eu
cd "$(dirname "${BASH_SOURCE[0]}")"

DOCKER_HOST=
ACTIVE_ENV_PATH=

# if the admin doesn't pass in the lnplay env file explicitly, then we use the "active_env.txt" method.
LNPLAY_ACTIVE_ENV_FILE="$(pwd)/active_env.txt"

# Stub out active_env.txt if doesn't exist. 
if [ ! -f "$LNPLAY_ACTIVE_ENV_FILE" ]; then
    # stub one out
    echo "local.env" >> "$LNPLAY_ACTIVE_ENV_FILE"
    echo "INFO: '$LNPLAY_ACTIVE_ENV_FILE' was just stubbed out."
fi

# now set the active env path to LNPLAY_ACTIVE_ENV_FILE if defined, otherwise whatever is set in the LNPLAY_ACTIVE_ENV_FILE
if [ -n "$LNPLAY_ENV_FILE_PATH" ]; then
    ACTIVE_ENV_PATH="$LNPLAY_ACTIVE_ENV_FILE"
else
    ACTIVE_ENV_PATH="$(pwd)/environments/""$(< "$LNPLAY_ACTIVE_ENV_FILE" head -n1 | awk '{print $1;}')"
fi

if [ -z "$ACTIVE_ENV_PATH" ]; then
    echo "ERROR: ACTIVE_ENV_PATH was not set correctly."
    exit 1
fi

if [ ! -f "$ACTIVE_ENV_PATH" ]; then
    cat > "$ACTIVE_ENV_PATH" << EOF
DOCKER_HOST=ssh://ubuntu@domain.tld
DOMAIN_NAME=domain.tld
ENABLE_TLS=true

EOF
    exit 1
fi

source "$ACTIVE_ENV_PATH"

if [ "$DOMAIN_NAME" = "domain.tld" ]; then
    echo "ERROR: Hey, you didn't update your env file '$ACTIVE_ENV_PATH'!"
    exit 1
fi

if [ "$DOMAIN_NAME" = "127.0.0.1" ] && [ "$ENABLE_TLS" = true ]; then
    echo "ERROR: Hey, you can't use TLS when your DOMAIN_NAME is equal to 127.0.0.1"
    exit 1
fi

if ! [[ $CLN_COUNT =~ ^[0-9]+$ ]]; then
    echo "ERROR: CLN_COUNT MUST be a positive integer."
    exit 1
fi

export DOCKER_HOST="$DOCKER_HOST"
export DOMAIN_NAME="$DOMAIN_NAME"
export ENABLE_TLS="$ENABLE_TLS"
export BTC_CHAIN="$BTC_CHAIN"
export NAMES_FILE_PATH="$NAMES_FILE_PATH"
export COLORS_FILE_PATH="$COLORS_FILE_PATH"

export LNPLAY_SERVER_PATH="$LNPLAY_SERVER_PATH"
export DIRECT_LINK_FRONTEND_URL_OVERRIDE_FQDN="$DIRECT_LINK_FRONTEND_URL_OVERRIDE_FQDN"
export ENABLE_CLAMS_V2_CONNECTION_STRINGS="$ENABLE_CLAMS_V2_CONNECTION_STRINGS"
export CLIGHTNING_WEBSOCKET_EXTERNAL_PORT="$CLIGHTNING_WEBSOCKET_EXTERNAL_PORT"