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
        ;;
    esac
done

# need to check that we are in swarm mode if we are running down.sh for the first time one a remote dockerd
if docker info | grep -q "Swarm: inactive"; then
    if docker stack list | grep -q "roygbiv-stack"; then
        echo "ERROR: the 'roygbiv-stack' is currently active. You may need to run ./down.sh or ./reset.sh first."
        exit 1
    fi
fi

if [ -f ./docker-compose.yml ]; then
    TIME_PER_CLN_NODE=3
    if docker stack ls --format "{{.Name}}" | grep -q roygbiv-stack; then
        docker stack rm roygbiv-stack && sleep $((CLN_COUNT * TIME_PER_CLN_NODE))
        sleep 5
    fi
fi

cd ..

# remove any container runtimes.
docker system prune -f

# remote dangling/unnamed volumes.
docker volume prune -f

sleep 2


# let's delete all volumes EXCEPT roygbiv-certs
if [ "$PURGE" = true ]; then

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
