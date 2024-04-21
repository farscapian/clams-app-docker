#!/bin/bash

set -exu

# get the BOLT12 any offers
mapfile -t anyoffers < "$LNPLAY_SERVER_PATH/any_offers.txt"
mapfile -t nodepubkeys < "$LNPLAY_SERVER_PATH/node_pubkeys.txt"
mapfile -t names < "$NAMES_FILE_PATH"

# start the createprism json string
PRISM_JSON_STRING="["

# create a JSON string with of the members[] definition
for ((CLN_ID=2; CLN_ID<CLN_COUNT; CLN_ID++)); do
    NODE_ANYOFFER=${anyoffers[$CLN_ID]}
    NODE_ID_FOR_KEYSEND=${nodepubkeys[$CLN_ID]}
    DESTINATION="$NODE_ANYOFFER"
    if [ $((CLN_ID % 2)) -eq 1 ]; then
        DESTINATION="$NODE_ID_FOR_KEYSEND"
    fi

    PRISM_JSON_STRING="${PRISM_JSON_STRING}{\"label\" : \"${names[$CLN_ID]}\", \"destination\": \"$DESTINATION\", \"split\": 1},"
done

# close off the json
PRISM_JSON_STRING="${PRISM_JSON_STRING::-1}]"

# if the prism doesn't already exist, we create it
#EXISTING_PRISM_IDS=$(./lightning-cli.sh --id=1 prism-list | jq -r '.[].prism_id')
#PRISM_ID_1="$BACKEND_FQDN-prism_demo"

# let's create 3 prisms
../lightning-cli.sh --id=1 prism-create -k prism_id="prism1" members="$PRISM_JSON_STRING"
# ../lightning-cli.sh --id=1 prism-create -k prism_id="prism2" members="$PRISM_JSON_STRING" 
# ../lightning-cli.sh --id=1 prism-create -k prism_id="prism3" members="$PRISM_JSON_STRING"


# now let's create offers
OFFER_ID_A=$(../lightning-cli.sh --id=1 offer -k amount=any description="offer_a" label="offer_a" | jq -r '.offer_id')
# OFFER_ID_B=$(../lightning-cli.sh --id=1 offer -k amount=any description="offer_b" label="offer_b" | jq -r '.offer_id')
# OFFER_ID_C=$(../lightning-cli.sh --id=1 offer -k amount=any description="offer_c" label="offer_c" | jq -r '.offer_id')

# now lets bind prism1 to offer_a. This is valid.
../lightning-cli.sh --id=1 prism-bindingadd -k prism_id="prism1" bind_to="$OFFER_ID_A"

# sleep 5
# # binding again simply replaces the prism given a distinct offer.
# ../lightning-cli.sh --id=1 prism-bindingadd -k prism_id="prism2" bind_to="$OFFER_ID_A"

# # ok let's bind prism1 to offer_b. This is valid.
# ../lightning-cli.sh --id=1 prism-bindingadd -k prism_id="prism1" bind_to="$OFFER_ID_B"

# # Let's just add another typical binding.
# ../lightning-cli.sh --id=1 prism-bindingadd -k prism_id="prism3" bind_to="$OFFER_ID_C"


# # ok, so now let's execute some manual payouts to ensure the splits are working.

# # 10k sats
# # test prism.pay
# AMOUNT_TO_PAY_MSAT="10000000"
# ../lightning-cli.sh --id=1 prism-pay -k prism_id="prism1" amount_msat="$AMOUNT_TO_PAY_MSAT"
# sleep 1
# ../lightning-cli.sh --id=1 prism-pay -k prism_id="prism2" amount_msat="$AMOUNT_TO_PAY_MSAT"
# sleep 1
# ../lightning-cli.sh --id=1 prism-pay -k prism_id="prism3" amount_msat="$AMOUNT_TO_PAY_MSAT"

# # now let's create a bolt11 invoice and bind prism2 to it.
# BOLT11_INVOICE_LABEL="BOLT11-001"
# ../lightning-cli.sh --id=1 invoice -k amount_msat="$AMOUNT_TO_PAY_MSAT" label="$BOLT11_INVOICE_LABEL" description="test123"
# sleep 1
# ../lightning-cli.sh --id=1 prism-bindingadd -k prism_id="prism2" bind_to="$BOLT11_INVOICE_LABEL" bolt_version="bolt11"
