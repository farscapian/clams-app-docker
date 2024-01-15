#!/bin/bash

set -exu

if [ "$BACKEND_DOMAIN_NAME" != "127.0.0.1" ]; then
    read -r -p "WARNING: You are targeting a remote LNPlay instance at '$BACKEND_DOMAIN_NAME'. Are you sure you want to continue? (yes/no): " ANSWSER

    # Convert the answer to lowercase
    ANSWER=$(echo "$ANSWSER" | tr '[:upper:]' '[:lower:]')

    # Check if the answer is "yes"
    if [ "$ANSWER" != "yes" ]; then
        echo "Quitting."
        exit 1
    fi
fi
