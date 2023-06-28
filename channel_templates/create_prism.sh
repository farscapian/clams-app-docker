#!/bin/bash

set -eu
cd "$(dirname "$0")" || exit 1

lncli() {
    "./../lightning-cli.sh" "$@"
}

mapfile -t pubkeys < node_pubkeys.txt

CAROL_PUBKEY=${pubkeys[2]}
DAVE_PUBKEY=${pubkeys[3]}
ERIN_PUBKEY=${pubkeys[4]}

PRISM_NAME="ROYGBIV Demo"
PRISMS=$(lncli --id=1 listprisms)
PRISM=

if ! echo "$PRISMS" | jq -r '.[].label' | grep -q "$PRISM_NAME"; then
    PRISM=$(lncli --id=1 createprism label="'"$PRISM_NAME"'" members='[{"name":"carol", "destination": "'"$CAROL_PUBKEY"'", "split": 1}, {"name": "dave", "destination": "'"$DAVE_PUBKEY"'", "split": 5}, {"name": "erin", "destination": "'"$ERIN_PUBKEY"'", "split": 2}]' 2>&1)
else
    PRISM="$PRISMS"
fi

echo "$PRISM"
