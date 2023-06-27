#!/bin/bash

set -eu
cd "$(dirname "$0")"

# this script tears everything down that might be up. It does not destroy data.

./defaults.env
./load_env.sh

if [ "$DO_NOT_DEPLOY" = true ]; then
    echo "INFO: The DO_NOT_DEPLOY was set to true in your environment file. You need to remove this before this script will execute."
    exit 1
fi

if echo "$ACTIVE_ENV" | grep -q "mainnet"; then
    read -p "WARNING: You are targeting a mainnet node! Are you sure you want to continue? (Y):  " ANSWER

    if [[ "$ANSWER" != "Y" ]]; then
        echo "exiting"
        exit 1
    fi
fi


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

# ensure all docker related processes have quit.
SLEEP_TIME=1
if [ "$BTC_CHAIN" = mainnet ]; then SLEEP_TIME=5; fi
while [ "$(docker ps -q)" ]; do
    sleep $SLEEP_TIME
done
sleep $SLEEP_TIME
