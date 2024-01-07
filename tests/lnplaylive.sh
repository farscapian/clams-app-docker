#!/bin/bash

set -exu
cd "$(dirname "$0")"

# purpose of script is to execute the complete payment workflow.
# so it uses the CLI to get a an order (including BOLT11 invoice)
# then it checks the invoice status to ensure it's unpaid.
# then we go ahead and pay the invoice, the check the status again to ensure it's paid.

# once this script is executed, a developer can watch the STDOUT of the CLN_ID=1
# where the lnplaylive plugin is executed. The provisioning workflow proceeds ONLY AFTER an
# invoice is paid, but only when the said invoice is related to lnplay.live orders 
# (the CLN node may have transactions unrelated to lnplaylive)

../reload_dev_plugins.sh

NODE_COUNT=8
HOURS=1

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --nodes=*)
            NODE_COUNT="${i#*=}"
            shift
        ;;
        --hours=*)
            HOURS="${i#*=}"
            shift
        ;;
        *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
done

LNPLAYLIVE_NODE=
if [ "BTC_CHAIN" = mainnet ]; then
    echo "ERROR: You can only run this on a regtest environment."
    exit 1
fi

CREATE_ORDER_RESPONSE=$(../lightning-cli.sh --id=1 -k lnplaylive-createorder node_count="$NODE_COUNT" hours="$HOURS")
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
SECOND_INVOICE_CHECK_STATUS="$(echo "$SECOND_INVOICE_CHECK_RESPONSE" | jq '.invoice_status' | xargs)"

if [ "$SECOND_INVOICE_CHECK_STATUS" != "paid" ]; then
    echo "ERROR: The status should say 'paid'"
    exit 1
fi

echo "SUCCESS! The backend process is now executing."

# TODO write some more logic here to ensure that we get connection strings!


