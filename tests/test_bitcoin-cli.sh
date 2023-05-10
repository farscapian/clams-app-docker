#! /bin/bash

# these tests make sure bitcoin-cli.sh is at least able to communicate with our bitcoin node 


blockchain_info="$(bcli getblockchaininfo 2>&1)"

if [ $? -ne 0 ]; then
  echo "Error: bitcoin-cli getblockchaininfo failed: $blockchain_info"
  exit 1
fi

expected_keys='["bestblockhash","blocks","chain","chainwork","difficulty","headers","initialblockdownload","mediantime","pruned","size_on_disk","time","verificationprogress","warnings"]'

actual_keys=$(bcli getblockchaininfo | jq -c 'keys | sort' 2>&1)

if [[ "$actual_keys" != "$expected_keys" ]]; then
  echo "Error: bitcoin-cli did not return the expected output."
  echo "Expected keys: $expected_keys, got: $actual_keys"
  exit 1
fi


actual_chain=$(bcli getblockchaininfo | jq -r ".chain")

if [[ "$actual_chain" != "$BTC_CHAIN" ]]; then
  echo "Error: bitcoind is running on $actual_chain and you are targeting $BTC_CHAIN"
  exit 1
fi

echo "PASSED: bitcoin-cli.sh is working as expected"
