#!/bin/bash

set -ex

mapfile -t pubkeys < node_pubkeys.txt


# let's wait for an output to exist before we start any channels.
OUTPUT_EXISTS=false
while ((OUTPUT_EXIST = false)); do
    # pool to ensure we have enough outputs to spend with.
    OUTPUT_EXISTS=$(lncli --id="$CLN_ID" listfunds | jq '.outputs | length > 0')

    # if at least one output exists in the CLN node, then we know
    # the node has been funded previously, and we can therefore skip
    if [ "$OUTPUT_EXISTS" = true ]; then
        echo "INFO: cln-$CLN_ID has sufficient funds: $BALANCE_MSAT mSats"
        break
    fi
done





# get node pubkeys
#ALICE_PUBKEY=$(lncli --id=0 getinfo | jq -r ".id")
BOB_PUBKEY=${pubkeys[1]}
CAROL_PUBKEY=${pubkeys[2]}
DAVE_PUBKEY=${pubkeys[3]}
ERIN_PUBKEY=${pubkeys[4]}

# now lets wire them up
# Alice --> Bob
lncli --id=0 fundchannel "$BOB_PUBKEY" 6000000 > /dev/null
echo "Alice opened a channel to Bob"

sleep 20

# Bob --> Carol
lncli --id=1 fundchannel "$CAROL_PUBKEY" 2000000 > /dev/null
echo "Bob opened a channel to Carol"
bcli -generate 3 > /dev/null


sleep 20

# Bob --> Dave
lncli --id=1 fundchannel "$DAVE_PUBKEY" 2000000 > /dev/null
echo "Bob opened a channel to Dave"
bcli -generate 3 > /dev/null


sleep 20

#  Bob --> Erin
lncli --id=1 fundchannel "$ERIN_PUBKEY" 2000000 > /dev/null
echo "Bob opened a channel to Erin"
bcli -generate 10 > /dev/null


sleep 20