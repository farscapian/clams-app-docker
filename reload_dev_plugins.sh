#!/bin/bash

set -eu
cd "$(dirname "$0")"

. ./defaults.env
. ./load_env.sh

DEV_PLUGIN_PATH="$(pwd)/lnplay/clightning/cln-plugins"

function reload_plugin {

    if [ "$1" = true ]; then
        for ((CLN_ID=0; CLN_ID<"$CLN_COUNT"; CLN_ID++)); do

            SCRIPTS="$2"

            # iterate over py scripts.
            for PLUGIN_FILENAME in $SCRIPTS; do
                chmod +x "$DEV_PLUGIN_PATH/$3/$PLUGIN_FILENAME"
                FILE_NAME=$(basename "$DEV_PLUGIN_PATH/$3/$PLUGIN_FILENAME")

                PLUGIN_LOADED=false
                PLUGIN_LIST_OUTPUT=$(./lightning-cli.sh --id="$CLN_ID" plugin list)
                if echo "$PLUGIN_LIST_OUTPUT" | grep -q "$FILE_NAME"; then
                    PLUGIN_LOADED=true
                fi

                if [ "$PLUGIN_LOADED" = true ]; then
                    ./lightning-cli.sh --id="$CLN_ID" plugin stop "/cln-plugins/$3/$FILE_NAME" > /dev/null
                fi

                ./lightning-cli.sh --id="$CLN_ID" plugin start "/cln-plugins/$3/$FILE_NAME" > /dev/null
                echo "INFO: Plugin '$FILE_NAME' is available on 'cln-$CLN_ID'."
            done
        done
    fi
}

if [ "$DEPLOY_RECKLESS_WRAPPER_PLUGIN"  = true ]; then
    reload_plugin "$DEPLOY_RECKLESS_WRAPPER_PLUGIN" "reckless-wrapper.py" "cln-reckless-wrapper"
fi

if [ "$DEPLOY_PRISM_PLUGIN"  = true ]; then
    reload_plugin "$DEPLOY_PRISM_PLUGIN" "bolt12-prism.py" "bolt12-prism"
    #reload_plugin "$DEPLOY_PRISM_PLUGIN" "prism-payer.py" "bolt12-prism"
fi

if [ "$DEPLOY_LNPLAYLIVE_PLUGIN"  = true ]; then
    reload_plugin "$DEPLOY_LNPLAYLIVE_PLUGIN" "lnplay-live-api.py" "lnplaylive"
fi

if [ "$DEPLOY_LNPLAYLIVE_PLUGIN"  = true ]; then
    reload_plugin "$DEPLOY_LNPLAYLIVE_PLUGIN" "invoice_paid.py" "lnplaylive"
fi
