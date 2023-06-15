#!/bin/bash

set -e

NODE_ID=0
SESSION_ID=

READ_PERMISSIONS=false
PAY_PERMISSIONS=false
LIST_PRISMS_PERMISSIONS=false
CREATE_PRISM_PERMISSIONS=false
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
            shift
        ;;
        --pay)
            READ_PERMISSIONS=true
            PAY_PERMISSIONS=true
            shift
        ;;
        --listprisms)
            LIST_PRISMS_PERMISSIONS=true
            shift
        ;;
        --createprism)
            LIST_PRISMS_PERMISSIONS=true
            CREATE_PRISM_PERMISSIONS=true
            shift
        ;;
        *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
done

RUNE_JSON=

if [ "$READ_PERMISSIONS" = false ] && [ "$READ_PERMISSIONS" = false ] && [ "$READ_PERMISSIONS" = false ] && [ "$READ_PERMISSIONS" = false ]; then
    echo "ERROR: You MUST specify at least one permission."
    exit 1
fi

CMD="./lightning-cli.sh --id=${NODE_ID} commando-rune restrictions='["

if [ -n "$SESSION_ID" ]; then
    CMD="${CMD}[\"id=$SESSION_ID\"],"
fi

if [ "$READ_PERMISSIONS" = true ]; then
    CMD="${CMD}[\"method^list\",\"method^get\",\"method=summary\",\"method=waitanyinvoice\",\"method=waitinvoice\",\"method/listdatastore\","
fi

if [ "$PAY_PERMISSIONS" = true ]; then
    CMD="${CMD}\"method=pay\",\"method=fetchinvoice\","
fi

if [ "$LIST_PRISMS_PERMISSIONS" = true ]; then
    CMD="${CMD}\"method=listprisms\","
fi

if [ "$CREATE_PRISM_PERMISSIONS" = true ]; then
    CMD="${CMD}\"method=createprism\","
fi

CMD="${CMD}],[\"rate=$RATE_LIMIT\"]]'"

RUNE_JSON=$(eval "$CMD")

if [ -n "$RUNE_JSON" ]; then
    RUNE=$(echo "$RUNE_JSON" | jq -r '.rune')
    echo "${RUNE}"
else
    echo "ERROR: the command did not complete."
    exit 1
fi