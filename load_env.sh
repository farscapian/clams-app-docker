#!/bin/bash

set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

DOCKER_HOST=

# read in ./active_env then source the file if it exists. export variables.
ACTIVE_ENV=$(cat ./active_env | head -n1 | awk '{print $1;}')
export ACTIVE_ENV="$ACTIVE_ENV"


ENV_FILE="./environments/$ACTIVE_ENV"

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

export DOCKER_HOST="$DOCKER_HOST"
export DOMAIN_NAME="$DOMAIN_NAME"
export ENABLE_TLS="$ENABLE_TLS"
export BTC_CHAIN="$BTC_CHAIN"