#!/bin/bash

set -e
cd "$(dirname "$0")"

lncli() {
    "./../lightning-cli.sh" "$@"
}

export -f lncli

echo "==========================================="
echo "Running tests... one moment please!"

echo "Testing prism plugin"
./test_prism_plugin.sh


