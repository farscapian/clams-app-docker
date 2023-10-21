#!/bin/bash

set -eu
cd "$(dirname "$0")"

NODE_ID=
SESSION_ID=

READ_PERMISSIONS=false
PAY_PERMISSIONS=false
RECEIVE_PERMISSIONS=false
LIST_PAYS_PERMISSIONS=false
LIST_PRISMS_PERMISSIONS=false
CREATE_PRISM_PERMISSIONS=false
BKPR_PERMISSIONS=false
ADMIN_RUNE=false
RATE_LIMIT=60

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --id=*)
            NODE_ID="${i#*=}"
            shift
        ;;
        --session-id=*)
            SESSION_ID="${i#*=}"
            shift
        ;;
        --read)
            READ_PERMISSIONS=true
            LIST_PAYS_PERMISSIONS=true
            shift
        ;;
        --list-pays)
            LIST_PAYS_PERMISSIONS=true
            shift
        ;;
        --receive)
            READ_PERMISSIONS=true
            RECEIVE_PERMISSIONS=true
            shift
        ;;
        --bkpr)
            BKPR_PERMISSIONS=true
            shift
        ;;
        --pay)
            READ_PERMISSIONS=true
            PAY_PERMISSIONS=true
            shift
        ;;
        --list-prisms)
            LIST_PRISMS_PERMISSIONS=true
            shift
        ;;
        --create-prism)
            LIST_PRISMS_PERMISSIONS=true
            CREATE_PRISM_PERMISSIONS=true
            shift
        ;;
        --admin)
            ADMIN_RUNE=true
            shift
        ;;
        *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
done

if [ -z "$NODE_ID" ]; then
    echo "ERROR: You MUST specify a --node-id="
    exit 1
fi

if [ "$BTC_CHAIN" = mainnet ]; then
    RESPONSE=
    read -r -p "WARNING: You are on mainnet. Are you sure you want to issue a new rune? " RESPONSE
    if [ "$RESPONSE" != "y" ]; then
        echo "STOPPING."
        exit 1
    fi
fi

RUNE_JSON=

# TODO fix this logic here.
if [ "$READ_PERMISSIONS" = false ] && \
   [ "$PAY_PERMISSIONS" = false ] && \
   [ "$LIST_PRISMS_PERMISSIONS" = false ] && \
   [ "$LIST_PAYS_PERMISSIONS" = false ] && \
   [ "$CREATE_PRISM_PERMISSIONS" = false ] && \
   [ "$RECEIVE_PERMISSIONS" = false ] && \
   [ "$BKPR_PERMISSIONS" = false ] && \
   [ "$ADMIN_RUNE" = false ]; then
        echo "ERROR: You MUST specify at least one permission."
        exit 1
fi

CMD="./lightning-cli.sh --id=${NODE_ID} commando-rune"

if [ "$ADMIN_RUNE" = false ]; then
    CMD="${CMD} restrictions='["
    if [ -n "$SESSION_ID" ]; then
        CMD="${CMD}[\"id=$SESSION_ID\"],"
    fi

    if [ "$READ_PERMISSIONS" = true ]; then
        CMD="${CMD}[\"method/listdatastore\"],[\"method^list\",\"method^get\",\"method=waitanyinvoice\",\"method=waitinvoice\""
    fi

    if [ "$LIST_PAYS_PERMISSIONS" = true ]; then
        CMD="${CMD},\"method=listpays\""
    fi

    if [ "$RECEIVE_PERMISSIONS" = true ]; then
        CMD="${CMD},\"method=waitanyinvoice\",\"method=waitinvoice\",\"method=invoice\",\"method^offer\""
    fi

    if [ "$PAY_PERMISSIONS" = true ]; then
        CMD="${CMD},\"method=pay\",\"method=fetchinvoice\",\"method=createinvoice\""
    fi

    if [ "$BKPR_PERMISSIONS" = true ]; then
        CMD="${CMD},\"method~bkpr\""
    fi

    if [ "$LIST_PRISMS_PERMISSIONS" = true ]; then
        CMD="${CMD},\"method=listprisms\""
    fi

    if [ "$CREATE_PRISM_PERMISSIONS" = true ]; then
        CMD="${CMD},\"method=createprism\""
    fi

    CMD="${CMD}],[\"rate=$RATE_LIMIT\"]]'"
fi

CMD="${CMD//[,/[[}"
RUNE_JSON=$(eval "$CMD")

if [ -n "$RUNE_JSON" ]; then
    echo "$RUNE_JSON" | jq -r '.rune'
else
    echo "ERROR: the command did not complete."
    exit 1
fi