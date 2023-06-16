#!/bin/bash

set -e
cd "$(dirname "$0")"

# check dependencies
for cmd in urlencode; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "This script requires \"${cmd}\" to be installed.."
        exit 1
    fi
done

. ./defaults.env
. ./load_env.sh

names=(alice bob carol dave erin frank greg hannah ian jane kelly laura mario nick olivia)

# print out the CLN node URIs for the user.
for (( CLN_ID=0; CLN_ID<CLN_COUNT; CLN_ID++ )); do
    CLN_NAME=${names[$CLN_ID]}
    CLN_ALIAS="cln-${CLN_ID}"
    CLN_WEBSOCKET_PORT=$(( STARTING_WEBSOCKET_PORT+CLN_ID ))
    CLN_P2P_PORT=$(( STARTING_CLN_PTP_PORT+CLN_ID ))

    echo "$CLN_NAME ($CLN_ALIAS) connection info:"


    # RUNE=$(bash -c "./get_rune.sh --id=${CLN_ID} --type=prismeditor")
    # echo "  admin_rune: $RUNE"
    # echo ""

    # use the override if specified.
    if [ -n "$CLN_P2P_PORT_OVERRIDE" ]; then
        CLN_P2P_PORT="$CLN_P2P_PORT_OVERRIDE"
    fi

    CLN_P2P_URI=$(bash -c "./get_node_uri.sh --id=${CLN_ID} --port=${CLN_P2P_PORT}")
    echo "  p2p_uri: $CLN_P2P_URI"


    # now let's output the core lightning node URI so the user doesn't need to fetch that manually.
    CLN_WEBSOCKET_URI=$(bash -c "./get_node_uri.sh --id=${CLN_ID} --port=${CLN_WEBSOCKET_PORT}")
    echo "  websocket_uri: $CLN_WEBSOCKET_URI"

    WEBSOCKET_PROTOCOL=ws
    if [ "$ENABLE_TLS" = true ]; then
        WEBSOCKET_PROTOCOL=wss
    fi

    WEBSOCKET_PROXY="${WEBSOCKET_PROTOCOL}://${DOMAIN_NAME}:${CLN_WEBSOCKET_PORT}"
    echo "  websocket_proxy: $WEBSOCKET_PROXY"

    echo ""

    P2P_QUERY_STRING="?type=p2p&uri=$CLN_P2P_URI"
    #&rune=$RUNE"
    echo "  p2p_query_string: $P2P_QUERY_STRING"

    WEBSOCKET_QUERY_STRING="?type=websocket&uri=$CLN_WEBSOCKET_URI&websocket_proxy=$WEBSOCKET_PROXY"
    #&rune=$RUNE"

    echo "  websocket_query_string: $WEBSOCKET_QUERY_STRING"
    echo ""

    # Encode to Base64
    BASE64_ENCODED_P2P_QUERY_STRING=$(echo -n "$P2P_QUERY_STRING" | base64)
    BASE64_URLENCODED_P2P_QUERY_STRING=$(urlencode "$BASE64_ENCODED_P2P_QUERY_STRING")

    BASE64_ENCODED_WEBSOCKET_QUERY_STRING=$(echo -n "$WEBSOCKET_QUERY_STRING" | base64)
    BASE64_URLENCODED_WEBSOCKET_QUERY_STRING=$(urlencode "$BASE64_ENCODED_WEBSOCKET_QUERY_STRING")
    echo "  base64_urlencoded_p2p_string: $BASE64_URLENCODED_P2P_QUERY_STRING"
    echo "  base64_urlencoded_websocket_string: $BASE64_URLENCODED_WEBSOCKET_QUERY_STRING"

    echo ""
    HTTP_PROT=http
    if [ "$ENABLE_TLS" = true ]; then HTTP_PROT=https; fi

    echo "  p2p_link: ${HTTP_PROT}://${DOMAIN_NAME}/$BASE64_URLENCODED_P2P_QUERY_STRING"
    echo "  websocket_link: ${HTTP_PROT}://${DOMAIN_NAME}/$BASE64_URLENCODED_WEBSOCKET_QUERY_STRING"

    echo ""

done
