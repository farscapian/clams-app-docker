#!/bin/bash

set -e
cd "$(dirname "$0")"

# this script delete various docker volumes containing applcation and/or user data
# use with care.

. ./defaults.env
. ./load_env.sh

./down.sh

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
            # we don't delete anything on mainnet. The administrator must do that
            # manually through the use of 'docker volume rm' command.
            if ! echo "$VOLUME" | grep -q mainnet; then
                docker volume rm "$VOLUME"
            else
                echo "INFO: The mainnet volume '$VOLUME' was NOT removed. You must run the following command manually:"
                echo "  docker volume rm $VOLUME"
            fi
        fi
    fi
done
