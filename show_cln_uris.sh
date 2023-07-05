#!/bin/bash

set -e
cd "$(dirname "$0")"

PRODUCE_QR_CODE=false

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --qrcode)
            PRODUCE_QR_CODE=true
            shift
        ;;
        *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
done

mkdir -p ./output

if [ "$PRODUCE_QR_CODE" = true ]; then
    if ! command -v qrencode >/dev/null 2>&1; then
        echo "This script requires qrencode to be installed.. Hint: apt-get install qrencode"
        exit 1
    fi

    mkdir -p ./output/qrcodes
fi


. ./defaults.env
. ./load_env.sh

readarray -t names < ./roygbiv/names.txt

OUTPUT_FILE="$(pwd)/output/cln_connection_info-${DOMAIN_NAME}.csv"
printf "" > "$OUTPUT_FILE"

echo "INFO: Writing direct links to $OUTPUT_FILE"

# print out the CLN node URIs for the user.
for (( CLN_ID=0; CLN_ID<CLN_COUNT; CLN_ID++ )); do
    CLN_NAME=${names[$CLN_ID]}
    CLN_ALIAS="cln-${CLN_ID}"
    CLN_WEBSOCKET_PORT=$(( STARTING_WEBSOCKET_PORT+CLN_ID ))
    # CLN_P2P_PORT=$(( STARTING_CLN_PTP_PORT+CLN_ID ))

    echo "$CLN_NAME ($CLN_ALIAS) connection info:"

    # # use the override if specified.
    # if [ -n "$CLN_P2P_PORT_OVERRIDE" ]; then
    #     CLN_P2P_PORT="$CLN_P2P_PORT_OVERRIDE"
    # fi

    #CLN_P2P_URI=$(bash -c "./get_node_uri.sh --id=${CLN_ID} --port=${CLN_P2P_PORT}")

    # now let's output the core lightning node URI so the user doesn't need to fetch that manually.
    CLN_WEBSOCKET_URI=$(bash -c "./get_node_uri.sh --id=${CLN_ID} --port=${CLN_WEBSOCKET_PORT}")

    echo "  websocket_uri: $CLN_WEBSOCKET_URI"
    PROTOCOL="ws:"
    if [ "$ENABLE_TLS" = true ]; then 
        PROTOCOL="wss:"
    fi

    RUNE=$(bash -c "./get_rune.sh --id=${CLN_ID} --admin")
    echo "  admin_rune: $RUNE"
    WEBSOCKET_QUERY_STRING="https://staging.app.clams.tech/connect?address=$CLN_WEBSOCKET_URI&type=direct&value=$PROTOCOL&rune=$RUNE"
    echo "$WEBSOCKET_QUERY_STRING" >> "$OUTPUT_FILE"

    if [ "$PRODUCE_QR_CODE" = true ]; then
        qrencode -o "$(pwd)/output/qrcodes/${DOMAIN_NAME}_cln-${CLN_ID}_websocket.png" -t png "$WEBSOCKET_QUERY_STRING"
    fi

    echo ""
done
