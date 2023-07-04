#!/bin/bash

set -e
cd "$(dirname "$0")"

echo "==========================================="
echo "Running tests... one moment please!"
echo "==========================================="

echo "Testing prism plugin"
./test_prism_plugin.sh
