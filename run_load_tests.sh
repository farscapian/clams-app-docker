#!/bin/bash

set -e
cd "$(dirname "$0")"

. ./defaults.env
. ./load_env.sh

export DOCKER_HOST=

OUTPUT_FILE="$(pwd)/output/cln_connection_info-${DOMAIN_NAME}.csv"

if [ ! -f "$OUTPUT_FILE" ]; then
    # ensure we have the correct input file containing connenction info
    ./show_cln_uris.sh --output-file="$OUTPUT_FILE"
fi

docker system prune -f

# next let's call the load testing script.
bash -c "./tests/load/run.sh --connection-csv-path=$OUTPUT_FILE"
