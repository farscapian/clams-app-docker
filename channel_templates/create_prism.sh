#!/bin/bash

set -u
cd "$(dirname "$0")" || exit 1

lncli() {
    "./../lightning-cli.sh" "$@"
}

mapfile -t pubkeys < node_pubkeys.txt

CAROL_PUBKEY=${pubkeys[2]}
DAVE_PUBKEY=${pubkeys[3]}
ERIN_PUBKEY=${pubkeys[4]}

prism=$(lncli --id=1 createprism label="ROYGBIV Demo" members='[{"name":"carol", "destination": "'"$CAROL_PUBKEY"'", "split": 1}, {"name": "dave", "destination": "'"$DAVE_PUBKEY"'", "split": 5}, {"name": "erin", "destination": "'"$ERIN_PUBKEY"'", "split": 2}]' 2>&1)

if [[ $? -ne 0 ]]; then
  echo "Error: Failed to create Prism offer"
  echo "$prism"
  exit 1
fi

echo "$prism"
