#!/bin/bash

set -e
cd "$(dirname "$0")"

echo "==========================================="
echo "Running tests... one moment please!"
echo "==========================================="

if [ "$CHANNEL_SETUP" = prism ]; then
    echo "Testing prism plugin"
    ./create_prism.sh
fi