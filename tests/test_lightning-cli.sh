#! /bin/bash


# these tests check that the lightning-cli script is at least able
# able to communicate with one node properly

lightning_info=$(lncli getinfo 2>&1)

if [ $? -ne 0 ]; then
  echo "Error: lncli getinfo failed: $lightning_info"
  exit 1
fi


expected_keys='["address","alias","binding","blockheight","color","fees_collected_msat","id","lightning-dir","msatoshi_fees_collected","network","num_active_channels","num_inactive_channels","num_peers","num_pending_channels","our_features","version"]'
actual_keys=$(lncli getinfo | jq -c 'keys | sort' 2>&1)


if [[ "$actual_keys" != "$expected_keys" ]]; then
  echo "Error: lightning-cli did not return the expected output."
  echo "Expected keys: $expected_keys, got: $actual_keys"
  exit 1
fi

echo "PASSED: lightning-cli.sh is working as expected"
