#!/bin/bash

set -eu
cd "$(dirname "$0")"

# close off the json
PRISM_JSON_STRING=$(cat ./prism.json)

echo "$PRISM_JSON_STRING"

# then run 
# ./lightning-cli.sh --id=0 prism-create -k "members=$PRISM_JSON_STRING" prism_id="roygbiv.guide/about" 
#outlay_factor=0.85714

# # if the prism doesn't already exist, we create it
# #EXISTING_PRISM_IDS=$(./lightning-cli.sh --id=1 prism-list | jq -r '.[].prism_id')
# #PRISM_ID_1="$BACKEND_FQDN-prism_demo"

# # let's create 3 prisms
# ../lightning-cli.sh --id=1 prism-create -k prism_id="prism1" members="$PRISM_JSON_STRING"
# ../lightning-cli.sh --id=1 prism-create -k prism_id="prism2" members="$PRISM_JSON_STRING" 
# ../lightning-cli.sh --id=1 prism-create -k prism_id="prism3" members="$PRISM_JSON_STRING"


# # now let's create offers
# OFFER_ID_A=$(../lightning-cli.sh --id=1 offer -k amount=any description="offer_a" label="prism1" | jq -r '.offer_id')
# OFFER_ID_B=$(../lightning-cli.sh --id=1 offer -k amount=any description="offer_b" label="offer2" | jq -r '.offer_id')
# #OFFER_ID_C=$(../lightning-cli.sh --id=1 offer -k amount=any description="offer_c" label="offer3" | jq -r '.offer_id')

# # now lets bind prism1 to offer_a. This is valid.
# ../lightning-cli.sh --id=1 prism-bindingadd -k prism_id="prism1" bind_to="$OFFER_ID_A"

# # now let's try to bind prism2 to offer_a. This is INVALID because there's already a binding
# ## this should fail
# ../lightning-cli.sh --id=1 prism-bindingadd -k prism_id="prism2" bind_to="$OFFER_ID_A"

# # ok let's bind prism1 to offer_b. This is still valid since offer_b has no existing bindings.
# ../lightning-cli.sh --id=1 prism-bindingadd -k prism_id="prism1" bind_to="$OFFER_ID_B"


# # ok, so now let's execute some manual payouts to ensure the splits are working.

# # 10k sats
# # test executepayout
# AMOUNT_TO_PAY_MSAT="10000000"
# ../lightning-cli.sh --id=1 prism-executepayout -k prism_id="prism1" amount_msat="$AMOUNT_TO_PAY_MSAT"
# # sleep 1
# # ../lightning-cli.sh --id=1 prism-executepayout -k prism_id="prism2" amount_msat="$AMOUNT_TO_PAY_MSAT"
# # sleep 1
# # ../lightning-cli.sh --id=1 prism-executepayout -k prism_id="prism3" amount_msat="$AMOUNT_TO_PAY_MSAT"

# # now let's create a bolt11 invoice and bind prism2 to it.
# BOLT11_INVOICE_LABEL="BOLT11-001"
# ../lightning-cli.sh --id=1 invoice -k amount_msat="$AMOUNT_TO_PAY_MSAT" label="$BOLT11_INVOICE_LABEL" description="test123"
# sleep 1
# ../lightning-cli.sh --id=1 prism-bindingadd -k prism_id="prism2" bind_to="$BOLT11_INVOICE_LABEL" bolt_version="bolt11"
