#!/bin/bash

set -exu
cd "$(dirname "$0")"

# now create a new BOLT12 any offer and grab the offer_id
OFFER=lno1qgsqvgnwgcg35z6ee2h3yczraddm72xrfua9uve2rlrm9deu7xyfzrc2pfg8y6tnd5sygetddutzzq3wa5w5cl6ane4hhv2drf4p5xwgzqu88fs709w8v9yjn99d3shels

# fetch an invoice
INVOICE=$(../lightning-cli.sh --id=0 fetchinvoice "$OFFER" 400000 | jq -r '.invoice')

# pay the bolt12 invoice.
../lightning-cli.sh --id=0 pay "$INVOICE"
