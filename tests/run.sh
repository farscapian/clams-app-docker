#!/bin/bash

set -e
cd "$(dirname "$0")"

if [ "$CHANNEL_SETUP" = prism ] && [ "$DEPLOY_PRISM_PLUGIN" = true ]; then
    ./create_prism.sh
fi

