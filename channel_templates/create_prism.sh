#!/bin/bash

set -exu

# get the BOLT12 any offers
mapfile -t anyoffers < "$LNPLAY_SERVER_PATH/any_offers.txt"
mapfile -t names < "$NAMES_FILE_PATH"

# start the createprism json string
PRISM_JSON_STRING="["

# create a JSON string with of the members[] definition
for ((CLN_ID=2; CLN_ID<CLN_COUNT; CLN_ID++)); do
    NODE_ANYOFFER=${anyoffers[$CLN_ID]}
    PRISM_JSON_STRING="${PRISM_JSON_STRING}{\"label\" : \"${names[$CLN_ID]}\", \"destination\": \"$NODE_ANYOFFER\", \"split\": $CLN_ID},"
done

# close off the json
PRISM_JSON_STRING="${PRISM_JSON_STRING::-1}]"

# if the prism doesn't already exist, we create it
#EXISTING_PRISM_IDS=$(./lightning-cli.sh --id=1 prism-list | jq -r '.[].prism_id')
#PRISM_ID_1="$BACKEND_FQDN-prism_demo"

../lightning-cli.sh --id=1 prism-create -k prism_id="prism1" members="$PRISM_JSON_STRING"

# now create a new BOLT12 any offer and grab the offer_id
OFFER_ID_A=$(../lightning-cli.sh --id=1 offer -k amount=any description="offer_a" label="prism1" | jq -r '.offer_id')

# now lets bind that prism to the offer
../lightning-cli.sh --id=1 prism-bindingadd -k prism_id="prism1" bolt_version=bolt12 bind_to="$OFFER_ID_A"

#prism_id="prism2"
../lightning-cli.sh --id=1 prism-create -k prism_id="prism2" members="$PRISM_JSON_STRING" 
../lightning-cli.sh --id=1 prism-create -k prism_id="prism3" members="$PRISM_JSON_STRING"
#prism_id="prism3"
# now create a new BOLT12 any offer and grab the offer_id
OFFER_ID_B=$(../lightning-cli.sh --id=1 offer -k amount=any description="offer_b" label="offer2" | jq -r '.offer_id')

# add some bindings.
../lightning-cli.sh --id=1 prism-bindingadd -k prism_id="prism2" bind_to="$OFFER_ID_B"
../lightning-cli.sh --id=1 prism-bindingadd -k prism_id="prism2" bind_to="$OFFER_ID_A"
../lightning-cli.sh --id=1 prism-bindingadd -k prism_id="prism3" bind_to="$OFFER_ID_A"

sleep 1

# 10k sats
AMOUNT_TO_PAY_MSAT="10000000"
../lightning-cli.sh --id=1 prism-pay -k prism_id="prism1" amount_msat="$AMOUNT_TO_PAY_MSAT"
sleep 1
../lightning-cli.sh --id=1 prism-pay -k prism_id="prism2" amount_msat="$AMOUNT_TO_PAY_MSAT"
sleep 1
../lightning-cli.sh --id=1 prism-pay -k prism_id="prism3" amount_msat="$AMOUNT_TO_PAY_MSAT"


# now let's create a bolt11 invoice and bind prism2 to it.
BOLT11_INVOICE_LABEL="BOLT11-002"
../lightning-cli.sh --id=1 invoice -k amount_msat="$AMOUNT_TO_PAY_MSAT" label="$BOLT11_INVOICE_LABEL" description="test123"
sleep 1
../lightning-cli.sh --id=1 prism-bindingadd -k prism_id="prism2" bind_to="$BOLT11_INVOICE_LABEL" bolt_version="bolt11"

sleep 1
