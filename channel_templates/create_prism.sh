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
    PRISM_JSON_STRING="${PRISM_JSON_STRING}{\"name\" : \"${names[$CLN_ID]}\", \"destination\": \"$NODE_ANYOFFER\", \"split\": $CLN_ID, \"type\":\"bolt12\"},"
done

# close off the json
PRISM_JSON_STRING="${PRISM_JSON_STRING::-1}]"

# create a prism
PRISM_ID="prism-$DOMAIN_NAME-prism_demo"
../lightning-cli.sh --id=1 prism-create -k members="$PRISM_JSON_STRING" prism_id="${PRISM_ID}"

# now let's create a BOLT12 entrypoint, then bind it to our prism.
OFFER_DESCRIPTION="Prism Demo"

# now create a new BOLT12 any offer and grab the offer_id
OFFER_ID=$(../lightning-cli.sh --id=1 offer -k amount=any description="$OFFER_DESCRIPTION" | jq -r '.offer_id')

# now lets bind that prism to the offer
../lightning-cli.sh --id=1 prism-bindingadd -k prism_id="$PRISM_ID" invoice_type=bolt12 invoice_label="$OFFER_ID"

echo "INFO: successfully created a BOLT12 prism on node 1."