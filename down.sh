#!/bin/bash

set -eu
cd "$(dirname "$0")"

# this script tears everything down that might be up. It does not destroy data.

. ./defaults.env

PURGE=false
PRUNE=true
NON_INTERACTIVE_MODE=false

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

        *)
        echo "Unexpected option: $1"
        exit 1
    esac
done

#LNPLAY_ACTIVE_ENV_FILE="$HOME/ss/projects/$(incus project list --format csv -q | grep "current" | cut -d' ' -f1)/lnplay.conf"
#export LNPLAY_ACTIVE_ENV_FILE="$LNPLAY_ACTIVE_ENV_FILE"

. ./load_env.sh

if [ "$DO_NOT_DEPLOY" = true ]; then
    echo "ERROR: the DO_NOT_DEPLOY flag is specified in your environment file. Can't do anything till that's gone yo."
    exit 1
fi

if [ "$BTC_CHAIN" = mainnet ]; then
    echo "WARNING: You are about to take down a mainnet node!"
    echo ""
    
    RESPONSE=
    read -r -p "         Are you sure you want to continue (y/n):  " RESPONSE
    if [ "$RESPONSE" != "y" ]; then
        echo "STOPPING."
        exit 1
    fi
fi

if [ "$NON_INTERACTIVE_MODE" = false ]; then
    ./prompt.sh
fi

if [ "$PURGE_VOLUMES_ON_DOWN" = true ]; then
    PURGE=true
fi

export LNPLAY_ENV_FILE_PATH="$LNPLAY_ENV_FILE_PATH"
export DOCKER_HOST="$DOCKER_HOST"

# we can check here to ensure the docker engine is in Swarm mode as expected, otherwise we 
# can just return
if docker info | grep -q "Swarm: inactive"; then
    echo "ERROR: ths docker engine is not in swarm mode!"
    exit 1
fi

sleep 0.1

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

# Interval in seconds between checks
INTERVAL=1
while true; do
    if ! docker ps --filter "status=running" --format "{{.Names}}" | grep -q "lnplay_"; then
        break
    else
        sleep "$INTERVAL"
    fi
done

if [ "$PRUNE" = true ]; then
    # remove any container runtimes.
    docker system prune -f > /dev/null
fi

# let's delete all volumes EXCEPT lnplay-certs, and obviously nothing related to mainnet
if [ "$PURGE" = true ]; then
    env BTC_CHAIN="$BTC_CHAIN" ./purge.sh > /dev/null
fi