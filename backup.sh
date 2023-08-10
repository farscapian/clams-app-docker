#!/bin/bash

# This scripts creates a backup of important docker volumes; 
# 1) any certificates in the roygbiv-certs volume
# 2) The prism path containing the wallet.dat file in the /var/lib/docker/volumes/roygbiv-stack_bitcoind-mainnet/_data/prism path
# 3) The lightning directory containing private keys for core lightning and the lightning database.
