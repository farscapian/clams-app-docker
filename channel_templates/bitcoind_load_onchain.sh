#!/bin/bash

# the purpose of this script is to ensure the bitcoind
# node has plenty of on-chain funds upon which to fund the CLN nodes.

set -eu
cd "$(dirname "$0")"

WALLET_INFO=$(bcli getwalletinfo)
# The above command will only work if only one wallet it loaded
# TODO: specify which wallet to target
WALLET_BALANCE=$(echo "$WALLET_INFO" | jq -r '.balance')
WALLET_NAME=$(echo "$WALLET_INFO" | jq -r '.walletname')

# min wallet balance is 1*CLN_COUNT; so each CLN node gets 1 BTC.
MIN_WALLET_BALANCE=0.0001
if [ "$BTC_CHAIN" = regtest ]; then
    ((MIN_WALLET_BALANCE = 1 * CLN_COUNT + 1))
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
