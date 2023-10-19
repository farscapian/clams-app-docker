#!/bin/bash

set -eu
cd "$(dirname "$0")"

# this script tears everything down that might be up. It does not destroy data.

. ./defaults.env

PURGE=false
PRUNE=true
NON_INTERACTIVE_MODE=false
LNPLAY_ENV_FILE_PATH=

if [ "$DO_NOT_DEPLOY" = true ]; then
    echo "INFO: The DO_NOT_DEPLOY was set to true in your environment file. You need to remove this before this script will execute."
    exit 1
fi

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --purge)
            PURGE=true
            shift
        ;;
        --non-interactive=*)
            NON_INTERACTIVE_MODE="${i#*=}"
            shift
        ;;
        --no-prune=*)
            PRUNE=false
            shift
        ;;
        --env-file=*)
            LNPLAY_ENV_FILE_PATH="${i#*=}"
            shift
        ;;
        *)
        echo "Unexpected option: $1"
        exit 1
    esac
done

. ./load_env.sh

if [ "$NON_INTERACTIVE_MODE" = false ]; then
    ./prompt.sh
fi

if [ "$PURGE_VOLUMES_ON_DOWN" = true ]; then
    PURGE=true
fi

export LNPLAY_ENV_FILE_PATH="$LNPLAY_ENV_FILE_PATH"
export DOCKER_HOST="$DOCKER_HOST"

# write out service for CLN; style is a docker stack deploy style,
# so we will use the replication feature
STACKS=$(docker stack ls --format "{{.Name}}")
for (( CLN_ID=CLN_COUNT; CLN_ID>=0; CLN_ID-- )); do
    STACK_NAME="lnplay-cln-${CLN_ID}"
    if echo "$STACKS" | grep -q "$STACK_NAME"; then
        docker stack rm "$STACK_NAME"
    fi
done

# now bring down the main lnplay.
if echo "$STACKS" | grep -q lnplay; then
    docker stack rm lnplay
fi

# wait until all containers are shut down.
i=0
while true; do
    CONTAINER_COUNT=$(docker ps -q | wc -l)
    if [ "$CONTAINER_COUNT" -gt 0 ]; then
        sleep 1
    else
        if [ "$i" -gt 0 ]; then
            sleep 3
            break
        else
            break
        fi
    fi

    i=$((i + 1))
done

if [ "$PRUNE" = true ]; then
    # remove any container runtimes.
    docker system prune -f
fi

# let's delete all volumes EXCEPT lnplay-certs
if [ "$PURGE" = true ]; then
    ./purge.sh
fi
