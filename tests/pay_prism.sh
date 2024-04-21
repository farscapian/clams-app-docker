#!/bin/bash

set -exu
cd "$(dirname "$0")"

# now create a new BOLT12 any offer and grab the offer_id
OFFER_A=$(../lightning-cli.sh --id=1 listoffers | jq -r '.offers[] | select(.label == "offer_a") | .bolt12')

# fetch an invoice
INVOICE=$(../lightning-cli.sh --id=0 fetchinvoice "$OFFER_A" 10000000 | jq -r '.invoice')

if [ -z "$INVOICE" ]; then
    echo "ERROR: INVOICE is not set."
    exit 1
fi

# pay the bolt12 invoice.
../lightning-cli.sh --id=0 pay "$INVOICE"
