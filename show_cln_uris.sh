#!/bin/bash

set -eu
cd "$(dirname "$0")"

PRODUCE_QR_CODE=false
OUTPUT_FILE=
SPAWN_BROWSER_TAB=false

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --qrcode)
            PRODUCE_QR_CODE=true
            shift
        ;;
        --output-file=*)
            OUTPUT_FILE="${i#*=}"
            shift
        ;;
        --browser)
            SPAWN_BROWSER_TAB=true
            shift
        ;;
        *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
done

if [ "$PRODUCE_QR_CODE" = true ]; then
    if ! command -v qrencode >/dev/null 2>&1; then
        echo "This script requires qrencode to be installed.. Hint: apt-get install qrencode"
        exit 1
    fi

    mkdir -p ./"$LNPLAY_SERVER_PATH"/qrcodes
fi

. ./defaults.env
. ./load_env.sh

if [ -z "$OUTPUT_FILE" ]; then
    OUTPUT_FILE="$LNPLAY_SERVER_PATH/${DOMAIN_NAME}.csv"""
fi

# print out the CLN node URIs for the user.
for (( CLN_ID=0; CLN_ID<CLN_COUNT; CLN_ID++ )); do

    # # for tabconf quit at 3
    # if [ "$CLN_ID" -ge 2 ]; then
    #     exit
    # fi


    CLN_WEBSOCKET_PORT=$(( STARTING_WEBSOCKET_PORT+CLN_ID ))

    # now let's output the core lightning node URI so the user doesn't need to fetch that manually.
    CLN_WEBSOCKET_URI=$(bash -c "./get_node_uri.sh --id=${CLN_ID} --port=${CLN_WEBSOCKET_PORT}")

    WSS_PROTOCOL="ws:"
    HTTP_PROTOCOL="http"
    if [ "$ENABLE_TLS" = true ]; then 
        WSS_PROTOCOL="wss:"
        HTTP_PROTOCOL="https"
    fi


    RUNE=
    if [ "$BTC_CHAIN" != mainnet ]; then
        RUNE=$(bash -c "./get_rune.sh --id=${CLN_ID} --admin")
    else
        RUNE=$(bash -c "./get_rune.sh --id=${CLN_ID} --admin")
    fi

    FRONT_END_FQDN="${DOMAIN_NAME}"

    # provide a way to override the front-end URL
    if [ -n "$DIRECT_LINK_FRONTEND_URL_OVERRIDE_FQDN" ]; then
        FRONT_END_FQDN="$DIRECT_LINK_FRONTEND_URL_OVERRIDE_FQDN"
        HTTP_PROTOCOL="https"
    fi

    # only put the port if it's non-standard.
    if [ "$BROWSER_APP_EXTERNAL_PORT" != 80 ] && [ "$BROWSER_APP_EXTERNAL_PORT" != 443 ]; then
        FRONT_END_FQDN="${FRONT_END_FQDN}:${BROWSER_APP_EXTERNAL_PORT}"
    fi

    WEBSOCKET_QUERY_STRING="${HTTP_PROTOCOL}://${FRONT_END_FQDN}/connect?address=${CLN_WEBSOCKET_URI}&type=direct&value=${WSS_PROTOCOL}&rune=${RUNE}"

    # if the output file is specified, write out the query string
    if [ -n "$OUTPUT_FILE" ]; then
        if [ "$CLN_ID" = 0 ]; then
            echo "$WEBSOCKET_QUERY_STRING" > "$OUTPUT_FILE"
        else
            echo "$WEBSOCKET_QUERY_STRING" >> "$OUTPUT_FILE"
        fi
    fi

    echo "$WEBSOCKET_QUERY_STRING"
    if [ "$PRODUCE_QR_CODE" = true ]; then
        qrencode -o "$(pwd)/output/qrcodes/${DOMAIN_NAME}_cln-${CLN_ID}_websocket.png" -t png "$WEBSOCKET_QUERY_STRING"
    fi

    if [ "$SPAWN_BROWSER_TAB" = true ]; then
        chromium --temp-profile --disable-extensions "$WEBSOCKET_QUERY_STRING" &
    fi
done
