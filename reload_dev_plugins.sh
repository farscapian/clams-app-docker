#!/bin/bash

set -eu
cd "$(dirname "$0")"

. ./defaults.env
. ./load_env.sh

if [ "$DOMAIN_NAME" != "127.0.0.1" ]; then
    echo "WARNING: in order to reload plugins on remote machines, the image must be updated."
    exit 0
fi

DEV_PLUGIN_PATH="$(pwd)/lnplay/clightning/cln-plugins/bolt12-prism"


# default is to reload all plugins on all nodes.
MAX_NODE_COUNT="$CLN_COUNT"
if [ "$DEPLOY_LNPLAYLIVE_PLUGIN" = true ]; then
    MAX_NODE_COUNT=1
fi

# fund each cln node
for ((CLN_ID=0; CLN_ID<"$MAX_NODE_COUNT"; CLN_ID++)); do

    if [ "$CLN_ID" -gt 1 ]; then
        exit 1
    fi

    # iterate over py scripts.
    for PLUGIN_FILENAME in "$DEV_PLUGIN_PATH"/*.py; do
        chmod +x "$PLUGIN_FILENAME"
        FILE_NAME=$(basename "$PLUGIN_FILENAME")

        PLUGIN_LOADED=false
        PLUGIN_LIST_OUTPUT=$(./lightning-cli.sh --id="$CLN_ID" plugin list)
        if echo "$PLUGIN_LIST_OUTPUT" | grep -q "$FILE_NAME"; then
            PLUGIN_LOADED=true
        fi

        if [ "$PLUGIN_LOADED" = true ]; then
            ./lightning-cli.sh --id="$CLN_ID" plugin stop "/cln-plugins/bolt12-prism/$FILE_NAME" > /dev/null
        fi

        ./lightning-cli.sh --id="$CLN_ID" plugin start "/cln-plugins/bolt12-prism/$FILE_NAME" > /dev/null
        echo "INFO: Plugin '$FILE_NAME' is available on 'cln-$CLN_ID'."
    done
done
