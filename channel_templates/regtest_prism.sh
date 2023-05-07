#!/bin/bash

set -e

mapfile -t pubkeys < node_pubkeys.txt

# get node pubkeys
#ALICE_PUBKEY=$(lncli --id=0 getinfo | jq -r ".id")
BOB_PUBKEY=${pubkeys[1]}
CAROL_PUBKEY=${pubkeys[2]}
DAVE_PUBKEY=${pubkeys[3]}
ERIN_PUBKEY=${pubkeys[4]}

# now lets wire them up
# Alice --> Bob
lncli --id=0 fundchannel "$BOB_PUBKEY" $((5000000))  > /dev/null
echo "Alice opened a channel to Bob"

# Bob --> Carol
lncli --id=1 fundchannel "$CAROL_PUBKEY" $((5000000))  > /dev/null
echo "Bob opened a channel to Carol"
bcli -generate 1  > /dev/null

# Bob --> Dave
lncli --id=1 fundchannel "$DAVE_PUBKEY" $((5000000))  > /dev/null
echo "Bob opened a channel to Dave"
bcli -generate 1  > /dev/null

#  Bob --> Erin
lncli --id=1 fundchannel "$ERIN_PUBKEY" $((5000000))  > /dev/null
echo "Bob opened a channel to Erin"
bcli -generate 10 > /dev/null
