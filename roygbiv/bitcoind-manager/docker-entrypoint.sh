#!/bin/bash

# the purpose of this script is to provide automated management of the bitcoind instance.
# in particular, this script will generate blocks every x seconds (configurable).
# if there are other things that needs to be done on an automated basis like this, we can
# put it here. But at the moment all I can think of is generating blocks.

while (true); do
    echo "TODO ISSUE A BLOCK"
    sleep "$BLOCK_TIME"
done