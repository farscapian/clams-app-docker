#!/bin/bash

set -eu
cd "$(dirname "$0")"

# this script delete various docker volumes containing applcation and/or user data
# use with care.

. ./defaults.env
. ./load_env.sh

if [ "$BTC_CHAIN" = mainnet ]; then
    echo "ERROR: you're on mainnet. You must delete mainnet volumes manually. For God's sake be careful."
    echo "       ensure you have the hsm_secret at a minimum. Creating an SCB is also advised."
    exit 1
fi


# remote dangling/unnamed volumes.
docker volume prune -f

# get a list of all the volumes
VOLUMES=$(docker volume list -q | grep lnplay-)

# Iterate over each value in the list
for VOLUME in $VOLUMES; do
    if echo "$VOLUME" | grep -q 'lnplay-certs'; then
        continue
    fi

    if echo "$VOLUME" | grep -q 'mainnet'; then
        echo "WARNING: there are mainnet volumes on this host. You should AVOID co-mingling mainnet with other environments."
    fi
    
    if echo "$VOLUME" | grep -q "-${BTC_CHAIN}"; then
        docker volume rm "$VOLUME"
    fi
done

rm -f "$LNPLAY_SERVER_PATH/node_addrs.txt"
rm -f "$LNPLAY_SERVER_PATH/node_pubkeys.txt"
rm -f "$LNPLAY_SERVER_PATH/any_offers.txt"
rm -f "$LNPLAY_SERVER_PATH/$DOMAIN_NAME.csv"

 docker image rm roygbiv/cln:23.08
 