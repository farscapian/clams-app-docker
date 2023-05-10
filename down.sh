#!/bin/bash

set -eu
cd "$(dirname "$0")"

# this script tears everything down that might be up. It does not destroy data.

source ./defaults.env
source ./load_env.sh

PURGE=false

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --purge)
            PURGE=true
            shift
        ;;
        --purge=*)
            PURGE="${i#*=}"
            shift
        ;;
        *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
done

# ensure we're using swarm mode.
if docker info | grep -q "Swarm: inactive"; then
    docker swarm init
fi

cd ./roygbiv/

if [ -f ./docker-compose.yml ]; then
    TIME_PER_CLN_NODE=5
    if docker stack ls --format "{{.Name}}" | grep -q roygbiv-stack; then
        docker stack rm roygbiv-stack && sleep $((CLN_COUNT * TIME_PER_CLN_NODE))
        sleep 5
    fi
fi

cd ..


# let's delete all volumes EXCEPT roygbiv-certs
if [ "$PURGE" = true ]; then

    # remove any container runtimes.
    docker system prune -f

    # remote dangling/unnamed volumes.
    docker volume prune -f

    sleep 2

    # get a list of all the volumes
    VOLUMES=$(docker volume list -q)

    # Iterate over each value in the list
    for VOLUME in $VOLUMES; do
        if ! echo "$VOLUME" | grep -q "roygbiv-certs"; then
            if echo "$VOLUME" | grep -q "roygbiv"; then
                docker volume rm "$VOLUME"
            fi
        fi
    done

fi
