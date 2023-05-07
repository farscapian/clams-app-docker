#!/bin/bash

# the purpose of this script is to ensure that all CLN nodes have on-chain funds.
# assumes bitcoind has a loaded wallet with spendable funds

set -e

mapfile -t node_addrs < node_addrs.txt

SENDMANY_JSON="{"
SEND_AMT=5

# fund each cln node
for ((CLN_ID=0; CLN_ID<CLN_COUNT; CLN_ID++)); do
    BALANCE_MSAT_STR=$(lncli --id="$CLN_ID" bkpr-listbalances | jq -r '.accounts[0].balances[0].balance_msat')
    BALANCE_MSAT=${BALANCE_MSAT_STR%msat}

    #check that we have at least 5 btc
    if (("$BALANCE_MSAT" > "$SEND_AMT" * 100000000000 )); then
        echo "INFO: cln-$CLN_ID has sufficient funds: $BALANCE_MSAT mSats"
        continue
    fi

    echo "Insufficient funds. Sending 5 btc to cln-$CLN_ID"
    CLN_ADDR=${node_addrs[$CLN_ID]}

    SENDMANY_JSON+="\"$CLN_ADDR\":$SEND_AMT,"

    if [ "$CLN_ID" = 1 ]; then
        for _ in {1...4}; do 
            bcli sendtoaddress "$CLN_ADDR" "$SEND_AMT" > /dev/null
        done
    fi
done

SENDMANY_JSON="${SENDMANY_JSON::-1}}"

bcli sendmany "" "$SENDMANY_JSON" > /dev/null

bcli -generate 10 > /dev/null

