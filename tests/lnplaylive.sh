#!/bin/bash

set -eu
cd "$(dirname "$0")"

../reload_dev_plugins.sh

CREATE_ORDER_RESPONSE=$(../lightning-cli.sh --id=1 -k lnplaylive-createorder node_count=8 hours=48)
echo "$CREATE_ORDER_RESPONSE"
INVOICE_ID="$(echo "$CREATE_ORDER_RESPONSE" | jq '.bolt11_invoice_id')"
FIRST_INVOICE_CHECK_RESPONSE="$(../lightning-cli.sh --id=1 -k lnplaylive-invoicestatus payment_type=bolt11 invoice_id="$INVOICE_ID")"
echo "$FIRST_INVOICE_CHECK_RESPONSE"
# get status
FIRST_INVOICE_CHECK_STATUS="$(echo "$FIRST_INVOICE_CHECK_RESPONSE" | jq '.invoice_status')"

if ! echo "$FIRST_INVOICE_CHECK_STATUS" | grep -q unpaid; then
    echo "ERROR: The status should say 'unpaid'"
    exit 1
fi


# now let's pay the invoice
BOLT11_INVOICE=$(echo "$CREATE_ORDER_RESPONSE" | jq '.bolt11_invoice')
../lightning-cli.sh --id=0 -k pay bolt11="$BOLT11_INVOICE" 



sleep 3
# get status
SECOND_INVOICE_CHECK_RESPONSE="$(../lightning-cli.sh --id=1 -k lnplaylive-invoicestatus payment_type=bolt11 invoice_id="$INVOICE_ID")"
SECOND_INVOICE_CHECK_STATUS="$(echo "$SECOND_INVOICE_CHECK_RESPONSE" | jq '.invoice_status')"


echo "$SECOND_INVOICE_CHECK_RESPONSE"

if [ "$SECOND_INVOICE_CHECK_STATUS" == "paid" ]; then
    echo "ERROR: The status should say 'paid'"
    exit 1
fi

echo "SUCCESS! All Test completed successfully."
