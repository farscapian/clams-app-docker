#!/bin/bash

set -eu
cd "$(dirname "$0")"

PURGE=true

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --purge)
            PURGE=true
            shift
        ;;
        *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
done



./down.sh "$@"

if [ "$PURGE" = true ]; then
    ./purge.sh
fi

./up.sh "$@"
