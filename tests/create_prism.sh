#!/bin/bash

set -eu
cd "$(dirname "$0")" || exit 1

lncli() {
    "./../lightning-cli.sh" "$@"
}

mapfile -t pubkeys < ../channel_templates/node_pubkeys.txt

CAROL_PUBKEY=${pubkeys[2]}
DAVE_PUBKEY=${pubkeys[3]}
ERIN_PUBKEY=${pubkeys[4]}


CAROL_OFFER=$(lncli offer any roygbiv_demo | jq -r '.bolt12')
DAVE_OFFER=$(lncli offer any roygbiv_demo | jq -r '.bolt12')
ERIN_OFFER=$(lncli offer any roygbiv_demo | jq -r '.bolt12')

PRISM_NAME="roygbiv_demo"
# if ! lncli --id=1 listprisms | jq -r '.[].label'; then
#     lncli --id=1 deleteprism "$PRISM_NAME"
# fi

lncli --id=1 createprism label=roygbiv_demo members='[{"name":"carol", "destination": "'"$CAROL_OFFER"'", "split": 5}, {"name": "dave", "destination": "'"$DAVE_OFFER"'", "split": 10}, {"name": "erin", "destination": "'"$ERIN_OFFER"'", "split": 2}]'
