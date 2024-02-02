#!/bin/bash

set -eu
cd "$(dirname "$0")"

. ./defaults.env
. ./load_env.sh

if [ "$BACKEND_FQDN" != "127.0.0.1" ]; then
    echo "WARNING: in order to reload plugins on remote machines, the image must be updated."
    exit 0
fi

#reload_plugin "$DEPLOY_PRISM_PLUGIN" "bolt12-prism.py" "bolt12-prism"


###################3 LNPLAYLIVE

# CLN_TARGET_ID=1
# if [ "$BTC_CHAIN" = mainnet ]; then
#     CLN_TARGET_ID=0
# fi

# # this only does lnplaylive
# PLUGIN_PATH="/cln-plugins/lnplaylive/invoice_paid.py"
# PLUGIN_IS_ACTIVE=$(./lightning-cli.sh --id="$CLN_TARGET_ID" plugin list | jq "[.plugins[] | select(.name == \"$PLUGIN_PATH\" and .active == true)] | length")
# if [ "$PLUGIN_IS_ACTIVE" -eq 1 ]; then
#     ./lightning-cli.sh --id="$CLN_TARGET_ID" plugin stop "$PLUGIN_PATH" >> /dev/null
# fi

# ./lightning-cli.sh --id=1 plugin start "$PLUGIN_PATH"


############## END LNPLAYLIVE

if [ "$DEPLOY_PRISM_PLUGIN" = true ]; then
    for ((CLN_ID=0; CLN_ID<"$CLN_COUNT"; CLN_ID++)); do

        SCRIPTS="prism.py"

        # iterate over py scripts.
        for PLUGIN_FILENAME in $SCRIPTS; do
            chmod +x "$DEV_PLUGIN_PATH/$PLUGIN_FILENAME"
            FILE_NAME=$(basename "$DEV_PLUGIN_PATH/$PLUGIN_FILENAME")

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
fi