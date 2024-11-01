#!/bin/bash

set -eu

# get the BOLT12 any offers
mapfile -t anyoffers < "$LNPLAY_SERVER_PATH/any_offers.txt"
mapfile -t names < "$NAMES_FILE_PATH"

# TODO; we need to ensure each CLN API is ready here; there's some weird issue with larger CLN_COUNTs.
sleep $((5 * REGTEST_BLOCK_TIME))

# start the createprism json string
PRISM_JSON_STRING="["

# create a JSON string with of the members[] definition
for ((CLN_ID=2; CLN_ID<CLN_COUNT; CLN_ID++)); do
    NODE_ANYOFFER=${anyoffers[$CLN_ID]}
    DESTINATION="$NODE_ANYOFFER"

    # we alternate the fees_incurred_by with remote/local
    FEES_INCURRED_BY="local"

    # pay out when threshold is over 500 sats
    PAYMENT_THRESHOLD_MSAT="0"
    SPLIT="1.0"
    # if odd
    if (( CLN_ID % 2 != 0)); then
        FEES_INCURRED_BY="remote"
        # payout instantly
        PAYMENT_THRESHOLD_MSAT="0"
        #DESTINATION=""
        #SPLIT="1"
    fi

    PRISM_JSON_STRING="${PRISM_JSON_STRING}{\"description\" : \"${names[$CLN_ID]}\", \"destination\": \"$DESTINATION\", \"split\": \"$SPLIT\", \"payout_threshold_msat\": \"$PAYMENT_THRESHOLD_MSAT\", \"fees_incurred_by\": \"$FEES_INCURRED_BY\"},"
done

# close off the json
PRISM_JSON_STRING="${PRISM_JSON_STRING::-1}]"

# if the prism doesn't already exist, we create it
#EXISTING_PRISM_IDS=$(./lightning-cli.sh --id=1 prism-list | jq -r '.[].prism_id')
#PRISM_ID_1="$BACKEND_FQDN-prism_demo"

# let's create 3 prisms
PRISM1_ID=$(../lightning-cli.sh --id=1 prism-create -k description="Band Prism" members="$PRISM_JSON_STRING" outlay_factor="0.75" | tee /dev/tty | jq -r '.prism_id')
#PRISM2_ID=$(../lightning-cli.sh --id=1 prism-create -k description="prism2" members="$PRISM_JSON_STRING" | tee /dev/tty  | jq -r '.prism_id')
#PRISM3_ID=$(../lightning-cli.sh --id=1 prism-create -k description="prism3" members="$PRISM_JSON_STRING" outlay_factor="1.1" | tee /dev/tty  | jq -r '.prism_id')


if [ "$PRISM1_ID" = null ]; then
    echo "Prism_ID was null."
    exit 1
fi

# now let's create offers
OFFER_ID_A=$(../lightning-cli.sh --id=1 offer -k amount=any description="Band Offer" label="band_prism_offer" | jq -r '.offer_id')
#OFFER_ID_B=$(../lightning-cli.sh --id=1 offer -k amount=any description="prism2_offer" label="prism2_offer" | jq -r '.offer_id')
#OFFER_ID_C=$(../lightning-cli.sh --id=1 offer -k amount=any description="prism3_offer" label="prism3_offer" | jq -r '.offer_id')

# now lets bind prism1 to prism1_offer. This is valid.
../lightning-cli.sh --id=1 prism-addbinding -k offer_id="$OFFER_ID_A" prism_id="$PRISM1_ID"

# binding again simply replaces the prism given a distinct offer.
#../lightning-cli.sh --id=1 prism-addbinding -k offer_id="$OFFER_ID_A" prism_id="$PRISM2_ID"

# ok let's bind prism1 to offer_b. This is valid.
#../lightning-cli.sh --id=1 prism-addbinding -k offer_id="$OFFER_ID_B" prism_id="$PRISM3_ID"

# Let's just add another typical binding.
#../lightning-cli.sh --id=1 prism-addbinding -k offer_id="$OFFER_ID_C" prism_id="$PRISM3_ID"


# ok, so now let's execute some manual payouts to ensure the splits are working.

# 10k sats
# test prism.pay
# AMOUNT_TO_PAY_MSAT="10000000"
# ../lightning-cli.sh --id=1 prism-pay -k prism_id="$PRISM1_ID" amount_msat="$AMOUNT_TO_PAY_MSAT"
# sleep 1
# ../lightning-cli.sh --id=1 prism-pay -k prism_id="$PRISM2_ID" amount_msat="$AMOUNT_TO_PAY_MSAT"
# sleep 1
# ../lightning-cli.sh --id=1 prism-pay -k prism_id="$PRISM3_ID" amount_msat="$AMOUNT_TO_PAY_MSAT"


