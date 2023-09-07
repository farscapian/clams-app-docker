#!/bin/bash

set -eu

# todo remove --admin and do least privilege
./get_rune.sh --id=1 --admin

## TODO, replace with 'createprism'

#./lightning-cli.sh --id=1 -k invoice amount_msat=500000 description="8 node environment." label="temp123"














##### BOLT12 VERSION ONLY - unfortunately, you actually get a BOLT12-specific invoice (not a BOLT11) when using BOLT11.
# create the product offers on Bob. Product-A is first.
PRODUCTA_OFFER_RESPONSE=$(./lightning-cli.sh --id=1 -k offer amount=5sat description="8 node environment." quantity_max=1344 label="lnplay.live - 8 node environment." issuer="lnplay.live")

BOLT12_PRODUCT_OFFER_A=$(echo "$PRODUCTA_OFFER_RESPONSE" | jq -r '.bolt12')
PRODUCTA_OFFER_ID=$(echo "$PRODUCTA_OFFER_RESPONSE" | jq -r '.offer_id')

BOLT12_PRODUCT_OFFER_B=$(./lightning-cli.sh --id=1 -k offer amount=6sat description="16 node environment." quantity_max=2688 label="lnplay.live - 16 node environment." issuer="lnplay.live" | jq -r '.bolt12')
BOLT12_PRODUCT_OFFER_C=$(./lightning-cli.sh --id=1 -k offer amount=7sat description="32 node environment." quantity_max=5376 label="lnplay.live - 32 node environment." issuer="lnplay.live" | jq -r '.bolt12')
BOLT12_PRODUCT_OFFER_D=$(./lightning-cli.sh --id=1 -k offer amount=8sat description="64 node environment." quantity_max=10752 label="lnplay.live - 64 node environment." issuer="lnplay.live" | jq -r '.bolt12')

# executed from alice, returns BOLT11/BOLT12 Invoice specific to this checkout.
BOLT11_INVOICE=$(./lightning-cli.sh --id=0 -k fetchinvoice offer="$BOLT12_PRODUCT_OFFER_A" quantity=16 | jq -r '.invoice')

# extract payment hash
PAYMENT_HASH=$(./lightning-cli.sh --id=0 -k decodepay bolt11="$BOLT11_INVOICE")

# wait for the BOLT 11invoice to be paid
while true; do
    ./lightning-cli.sh --id=1 -k listinvoices payment_hash="$PAYMENT_HASH"
    sleep 5
done

echo "Paid:"

# invoice is paid from external node using Lightning Network.

# 
# invoicerequest - command for offering payments
# waitinvoice
# waitanyinvoice
# sendinvoice 

#./lightning-cli.sh --id=0 -k waitinvoice