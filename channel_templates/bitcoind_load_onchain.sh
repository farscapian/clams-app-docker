#!/bin/bash

# the purpose of this script is to ensure the bitcoind
# node has plenty of on-chain funds upon which to fund the CLN nodes.

set -e
cd "$(dirname "$0")"

#first we need to check if the prism wallet exists in the wallet dir
if [[ $(bcli listwalletdir) == *'"name": "prism"'* ]]; then
    # load wallet if not already loaded
    if ! bcli listwallets | grep -q "prism"; then
        bcli loadwallet prism > /dev/null
    fi
else
    #create walllet (gets loaded automatically) if it does not already exist
    bcli createwallet prism > /dev/null
fi

WALLET_INFO=$(bcli getwalletinfo)
# The above command will only work if only one wallet it loaded
# TODO: specify which wallet to target
WALLET_BALANCE=$(echo "$WALLET_INFO" | jq -r '.balance')
WALLET_NAME=$(echo "$WALLET_INFO" | jq -r '.walletname')

echo "$WALLET_NAME wallet initialized"
MIN_WALLET_BALANCE=50
if [ "$BTC_CHAIN" = signet ]; then
    MIN_WALLET_BALANCE=0.0001
else
    MIN_WALLET_BALANCE=0.0001
fi

    
BTC_ADDRESS=$(bcli getnewaddress)
CLEAN_BTC_ADDRESS=$(echo -n "$BTC_ADDRESS" | tr -d '\r')
if [ "$BTC_CHAIN" == regtest ]; then

    # if the wallet balance is not big enough, we mine some blocks to ourselves
    if [ "$(echo "$WALLET_BALANCE < $MIN_WALLET_BALANCE" | bc -l) " -eq 1 ]; then

        # in regtest we can just generate some blocks; not so with signet and mainnet
        bcli generatetoaddress 105 "$CLEAN_BTC_ADDRESS" > /dev/null
        echo "105 blocks mined to $WALLET_NAME"

    fi

elif [ "$BTC_CHAIN" == signet ]; then
        
    # if the wallet doesn't have the minimum required, then we error out.
    # otherwise it's all good and we keep going.
    if [ "$(echo "$WALLET_BALANCE < $MIN_WALLET_BALANCE" | bc -l) " -eq 1 ]; then
        echo "WARNING: Your signet wallet is not funded. Send at least 0.01000000 signet coins to: ${CLEAN_BTC_ADDRESS}"
        echo "INFO:    Here's two faucets:"
        echo "           - https://signetfaucet.com/"
        echo "           - https://alt.signetfaucet.com/"
        exit 1
    fi

else
    if [ "$BTC_CHAIN" != mainnet ]; then
        # if the wallet doesn't have the minimum required, then we error out.
        # otherwise it's all good and we keep going.
        if [ "$(echo "$WALLET_BALANCE < $MIN_WALLET_BALANCE" | bc -l) " -eq 1 ]; then
            echo "WARNING: Your ${BTC_CHAIN} wallet is not properly funded. Send at least '$MINIMUM_WALLET_BALANCE' btc to: ${CLEAN_BTC_ADDRESS}"
        fi
    fi
fi
