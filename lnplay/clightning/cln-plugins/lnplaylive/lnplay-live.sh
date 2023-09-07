#!/bin/bash

set -eu

[[ -e /tmp/myplugin ]] && rm /tmp/myplugin

# getmanifest

read -r JSON
read -r _
# echo "$JSON" >> /tmp/myplugin
id=$(echo "$JSON" | jq .id)
echo '{"jsonrpc": "2.0", "id": '"$id"', "result": {"dynamic": true, "options": [{"name": "foo_opt", "type": "string", "default": "bar", "description": "description"}], "rpcmethods": [{"name": "lnlive-getinvoice", "usage": "", "description": "Returns a BOLT11 invoice for a"}]}}'

# init

read -r JSON
read -r _
# echo "$JSON" >> /tmp/myplugin
id=$(echo "$JSON" | jq .id)
foo_opt=$(echo "$JSON" | jq .params.options.foo_opt)
socket_path=$(echo "$JSON" | jq '.params.configuration."lightning-dir" + "/" + .params.configuration."rpc-file"' -r)

echo '{"jsonrpc": "2.0", "id": '"$id"', "result": {}}'

# i/o loop

while read -r JSON; do
    read -r _
    # echo "$JSON" >> /tmp/myplugin
    id=$(echo "$JSON" | jq .id)
    cli_params=$(echo "$JSON" | jq .params)
    read -r JSON_1 < <(echo '{"jsonrpc": "2.0", "id": "1", "method": "getinfo", "params": [], "filter": { "id": true }}' | nc -U "$socket_path")
    node_id=$(echo "$JSON_1" | jq .result.id)
    echo '{"jsonrpc": "2.0", "id": '"$id"', "result": {"id": '"$node_id"', "options": {"foo_opt": '"$foo_opt"'}, "cli_params": '"$cli_params"'}}'
done

echo ""