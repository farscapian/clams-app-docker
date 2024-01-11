#!/bin/bash

set -exu
cd "$(dirname "$0")"

# now create a new BOLT12 any offer and grab the offer_id
OFFER=$(../lightning-cli.sh --id=1 listoffers | jq -r '.offers[] | select(.label == "prism-127.0.0.1-prism_demo") | .bolt12')


# fetch an invoice
INVOICE=$(../lightning-cli.sh --id=0 fetchinvoice "$OFFER" 400000 | jq -r '.invoice')

if [ -z "$INVOICE" ]; then
    echo "ERROR: INVOICE is not set."
    exit 1
fi

# pay the bolt12 invoice.
../lightning-cli.sh --id=0 pay "$INVOICE"
