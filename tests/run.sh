#!/bin/bash

set -e
cd "$(dirname "$0")"

if [ "$CHANNEL_SETUP" = prism ]; then
    ./create_prism.sh
fi