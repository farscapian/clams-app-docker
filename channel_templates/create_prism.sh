#!/bin/bash

set -e
cd "$(dirname "$0")"

lncli() {
    "./../lightning-cli.sh" "$@"
}

mapfile -t pubkeys < node_pubkeys.txt

CAROL_PUBKEY=${pubkeys[2]}
DAVE_PUBKEY=${pubkeys[3]}
ERIN_PUBKEY=${pubkeys[4]}

prism=$(lncli --id=1 createprism label="'"$RANDOM"'" members='[{"name": "carol", "destination": "'"$CAROL_PUBKEY"'", "split": 1}, {"name": "dave", "destination": "'"$DAVE_PUBKEY"'", "split": 5}, {"name": "erin", "destination": "'"$ERIN_PUBKEY"'", "split": 2}]')

echo "$prism"
