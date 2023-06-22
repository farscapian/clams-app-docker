#!/bin/bash

set -eu
cd "$(dirname "$0")"

. ./defaults.env
. ./load_env.sh

# fund each cln node
for ((CLN_ID=0; CLN_ID<CLN_COUNT; CLN_ID++)); do
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
            ./lightning-cli.sh --id="$CLN_ID" plugin stop "/dev-plugins/$FILE_NAME" > /dev/null
        fi

        ./lightning-cli.sh --id="$CLN_ID" plugin start "/dev-plugins/$FILE_NAME" > /dev/null
        echo "INFO: Plugin '$FILE_NAME' has been reloaded on 'cln-$CLN_ID'."
    done
done
