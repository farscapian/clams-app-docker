#!/bin/bash
if [ "$ACTIVE_ENV" != "local.env" ] && [ "$USER_SAYS_YES" = false ]; then
    read -p -r "WARNING: You are targeting something OTHER than a dev/local instance. Are you sure you want to continue? (yes/no): " answer

    # Convert the answer to lowercase
    ANSWER=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

    # Check if the answer is "yes"
    if [ "$ANSWER" != "yes" ]; then
        echo "Quitting."
        exit 1
    fi
fi
