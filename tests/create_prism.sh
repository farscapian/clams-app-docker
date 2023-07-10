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


CAROL_OFFER=$(lncli --id=2 offer any roygbiv_demo | jq -r '.bolt12')
DAVE_OFFER=$(lncli --id=3 offer any roygbiv_demo | jq -r '.bolt12')
DAVE_ID=$(lncli --id=3 getinfo | jq -r '.id')
ERIN_OFFER=$(lncli --id=4 offer any roygbiv_demo | jq -r '.bolt12')

PRISM_NAME="roygbiv_demo-$(gpg --gen-random --armor 1 8 | tr -dc '[:alnum:]' | head -c10)"
PRISMS=$(lncli --id=1 listprisms)
PRISM_COUNT=$(echo "$PRISMS" | jq ".prisms | length")
if [ "$PRISM_COUNT" = 0 ]; then
    # select the offer_id of the first prism.
    PRISM_NAME="roygbiv_demo"
fi

echo "$(lncli --id=1 createprism label="\"$PRISM_NAME"\" members="[{\"name\" : \"carol\", \"destination\": \"$CAROL_OFFER\", \"split\": 5, \"type\":\"bolt12\"}, {\"name\": \"dave\", \"destination\": \"$DAVE_PUBKEY\", \"split\": 10, \"type\":\"keysend\"}, {\"name\": \"erin\", \"destination\": \"$ERIN_OFFER\", \"split\": 5, \"type\":\"bolt12\"}]")"
