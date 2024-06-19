#!/bin/bash

set -ex
cd "$(dirname "$0")"

OFFER_LABELS=("Band Prism") # "prism2_offer" "prism3_offer")

# Iterate over each offer
index=0
while true; do
    OFFER_LABEL="${OFFER_LABELS[$index]}"
    echo "Processing $OFFER_LABEL"
    ./pay_prism.sh --description="$OFFER_LABEL"
    index=$(( (index + 1) % ${#OFFER_LABELS[@]}))
done