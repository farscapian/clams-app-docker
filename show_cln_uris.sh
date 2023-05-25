#!/bin/bash

set -e
cd "$(dirname "$0")"

. ./defaults.env
. ./load_env.sh

# print out the CLN node URIs for the user.
for (( CLN_ID=0; CLN_ID<CLN_COUNT; CLN_ID++ )); do
    CLN_ALIAS="cln-${CLN_ID}"
    CLN_WEBSOCKET_PORT=$(( STARTING_WEBSOCKET_PORT+CLN_ID ))
    CLN_P2P_PORT=$(( STARTING_CLN_PTP_PORT+CLN_ID ))

    # now let's output the core lightning node URI so the user doesn't need to fetch that manually.
    CLN_WEBSOCKET_URI=$(bash -c "./get_node_uri.sh --id=${CLN_ID} --port=${CLN_WEBSOCKET_PORT}")
    echo "Websocket URI for '$CLN_ALIAS': $CLN_WEBSOCKET_URI"

    CLN_P2P_URI=$(bash -c "./get_node_uri.sh --id=${CLN_ID} --port=${CLN_P2P_PORT}")
    echo "Native P2P URI for '$CLN_ALIAS': $CLN_P2P_URI"

    if [ "$CLN_ID" = 1 ]; then
        PROTOCOL=ws
        if [ "$ENABLE_TLS" = true ]; then
            PROTOCOL=wss
        fi

        echo "Prism app WebSocket proxy string: ${PROTOCOL}://${DOMAIN_NAME}:${CLN_WEBSOCKET_PORT}"
    fi
    
    RUNE=$(bash -c "./get_rune.sh --id=${CLN_ID}")
    echo "Admin rune for ${CLN_ALIAS}: $RUNE"
    echo ""
done
